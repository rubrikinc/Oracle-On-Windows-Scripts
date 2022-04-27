  #Requires -modules Rubrik

<#

.SYNOPSIS

This PowerShell script will delete backed up archived logs from the Oracle host

.DESCRIPTION

This is a post backup script hat will delete archived logs from the oracle host that have been backed up. 
The ORACLE_SID should match the managed volume name or the managed volume name will need to be supplied. 
The MV_NAME is optional.

The ORACLE_HOME will can be determined from the registry settings as long as there is a registry key set under 
HKEY_LOCAL_MACHINE\SOFTWARE\ORACLE\KEY_(ora home name). If the ORACLE_HOME cannot be determined from the registry
an ORACLE_HOME parameter must be supplied. 

.EXAMPLE

This is called from the SLA MV. When setting the post script for the SLA MV use the format: powershell <script path>  <options>
powershell C:/Scripts/Rubrik_Oracle_SLAMV_Backup.ps1 -ORACLE_SID dbname -MV_NAME managed_volume_name -LOG

.NOTES
To prepare to use this script complete the following steps:
rce
1) Create the Rubrik event log source (if not already created): 
    From a Windows Powershell Administrative Shell run
        New-EventLog -Source Rubrik -LogName Application
2) Set Variables as necessary in script:
    a) Set Rubrik CDM address (Use Floating IP)
    b) Set appropriate credentials variable, $ApiTokenFile if using API Token, $CredentialFile if using User/passwork or 
    set $RubrikUser and $RubrikPasswork (Note: only use for tesing)
    c) Set the $Logdir path (make sure path exists)
3) Add this script to the combined or log only backup as a post script on successful backup.


Windows Events logged:
Event: Rubrik Connection Failed
Event Type: ERROR
Event ID: 55500

Event: Managed Volume Get Error
Event Type: ERROR
Event ID: 55503

Event: RMAN Backup Failed
Event Type: ERROR
Event ID: 55510

Event: RMAN Archivelog Delete Failed
Event Type: ERROR
Event ID: 55511

Event: RMAN Script Error
Event Type: ERROR
Event ID: 55512

Event: RMAN Backup Completed
Event Type: INFORMATION
Event ID: 55520
#>

param (
  # The Oracle Database sid
  [Parameter(Mandatory=$True,
  HelpMessage="Enter the Oracle Database sid.")]
  [string]$ORACLE_SID,

  # The Oracle Home
  [Parameter(Mandatory=$False,
  HelpMessage="Enter the ORACLE_HOME if not available in the Registry for this ORACLE_SID.")]
  [string]$ORACLE_HOME,

  # Set to do shutdown the database and start it up mounted only
  [Parameter(Mandatory=$False,
  HelpMessage="Use the MOUNT flag shutdown immediate and startup mount the datase.")]
  [switch]$MOUNT,

  # Set to open a mounted database
  [Parameter(Mandatory=$False,
  HelpMessage="Use the OPEN flag to open the mounted database")]
  [switch]$OPEN
)

###################################################
# Check and set the type of operation for the script run
###################################################
If ($MOUNT) {
    $ACTION = "mount"
} Elseif ($OPEN) {
    $ACTION = "open"
} Else {
    $Message = "Cold backup mount or open failed. Either MOUNT or OPEN must be specified"
    Write-Host $Message
    Write-EventLog -LogName "Application" `
    -Source "Rubrik" `
    -EntryType "Error" `
    -EventId 55512 `
    -Message $Message
    exit 1
}

###################################################
# Edit Variables for you environment
# Set Rubrik variables
###################################################
###################################################
# Log directory - This must exist for the script to run
$logdir = 'C:\Rubrik\logs'
# Log name format
$logname = $Oracle_SID + "_$($ACTION)_"
###################################################


###################################################
# Create log file
###################################################
$logdate = Get-Date -Format FileDateTime
$logdate = $logdate -replace ".{4}$"
$logfile = $logdir + '\' + $logname + $logdate + '.txt'
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
# Begin logging
Start-Transcript -path $logfile -append

###################################################
# Set up ORACLE SID
###################################################
IF ([string]::IsNullOrWhiteSpace($ORACLE_SID)) {
    Write-Host -ForegroundColor Red "Invalid number of parameters. The ORACLE_SID is required. Usage: Rubrik_Oracle_IM_Backup.ps1 -ORACLE_SID dbname" 
    exit 1
}

# If an ORACLE_HOME was not supplied, get the ORACLE_HOME from the registry
IF ([string]::IsNullOrWhiteSpace($ORACLE_HOME)) {
    # Find the ORACLE_HOME key for the ORACLE_SID
    $OHKEY=reg query HKEY_LOCAL_MACHINE\SOFTWARE\Oracle\ /s /e /f $ORACLE_SID /c | Select-String "\\KEY"
    IF ($null -eq $OHKEY) {
        Write-Host -ForegroundColor Red "Oracle SID '$ORACLE_SID' not found in the registry. Please verify SID name and case."
        exit 1
    }
    $OHKEY_VALUE=reg query $OHKEY /V ORACLE_HOME| Select-String REG_SZ
    $OHKEY_VALUE= -split $OHKEY_VALUE
    $ORACLE_HOME=$OHKEY_VALUE[2]  
}

# Set the environment for the database
Write-Host  -ForegroundColor Green "Using $ORACLE_HOME to set the environment variables for database $ORACLE_SID."
$Env:ORACLE_SID=$ORACLE_SID
$Env:ORACLE_HOME=$ORACLE_HOME
$env:NLS_DATE_FORMAT="MM/DD/YY HH24:MI:SS"


######################################################################
# Backup database if a database backup or a combined backup

if ($MOUNT) {
    Write-Output 'Shutting down database and starting up mounted for backup...'

    # Build RMAN backup with channels for the managed volume
    $SCRIPT = @"
    set echo on;
    shutdown immediate;
    startup mount;
    exit;
"@

    # Run the RMAN script and log results
    try{
        $SCRIPT | sqlplus / as sysdba | Write-Host
    } catch {
        $Message = "Error Running sqlplus" 
        $Message = $Message + "`nDatabase SID: $ORACLE_SID"
        $Message = $Message + "`nThere was an error running the sqlplus command to shutdown and mount the database."
        Write-Host $Message

        Write-EventLog -LogName "Application" `
            -Source "Rubrik" `
            -EntryType "Error" `
            -EventId 55510 `
            -Message $Message
        Stop-Transcript
        exit 1
    }

} Elseif ($OPEN) {
   Write-Output 'Open the mounted database after the backup...'

    # Build RMAN backup with channels for the managed volume
    $SCRIPT = @"
    set echo on;
    alter database open;
    exit;
"@

    # Run the RMAN script and log results
    try{
        $SCRIPT | sqlplus / as sysdba | Write-Host
    } catch {
        $Message = "Error Running sqlplus" 
        $Message = $Message + "`nDatabase SID: $ORACLE_SID"
        $Message = $Message + "`nThere was an error running the sqlplus command to open the mounted database."
        Write-Host $Message

        Write-EventLog -LogName "Application" `
            -Source "Rubrik" `
            -EntryType "Error" `
            -EventId 55510 `
            -Message $Message
        Stop-Transcript
        exit 1
    }

}


###################################################
# Check the log files for errors
###################################################
Write-Host "Parsing the log file for errors..."
# Find the ORA- errors in the log
$errors = Get-Content -path $logfile | Select-String "ORA-[0-9]"


if ($errors) {
    $Message = "Prepost Script Error" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nThe Error stopping or starting the database"
    $Message = $Message + "`nCheck the backup log: $logfile"
    foreach($line in $errors){$Message = $Message + "`n" + $line}
    Write-Host $Message

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55512 `
        -Message $Message
    Stop-Transcript
    exit 1
}
Write-Host "The log file looks good!"


###################################################
# Finish up log and send success event
###################################################
$Message = "RMAN archive log delete Completed" 
$Message = $Message + "`nDatabase SID: $ORACLE_SID"
$Message = $Message + "`nThe RMAN archive log deletion completed successfully."

Write-EventLog -LogName "Application" `
    -Source "Rubrik" `
    -EntryType "Information" `
    -EventId 55520 `
    -Message $Message
    Write-Host $Message

# End logging
Stop-Transcript
exit 0 
 
