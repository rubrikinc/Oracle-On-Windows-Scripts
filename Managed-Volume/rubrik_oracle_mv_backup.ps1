#Requires -modules Rubrik

<#

.SYNOPSIS

This PowerShell script will take a RMAN backup of an Oracle databae to a Rubrik Manged Volume

.DESCRIPTION

This script will build and run a dynamic RMAN backup. The ORACLE_SID should match the managed volume name 
or the managed volume name will need to be supplied. The MV_NAME is optional.

The ORACLE_HOME will can be determined from the registry settings as long as there is a registry key set under 
HKEY_LOCAL_MACHINE\SOFTWARE\ORACLE\KEY_(ora home name). If the ORACLE_HOME cannot be determined from the registry
an ORACLE_HOME parameter must be supplied. 

.EXAMPLE

.\Rubrik_Oracle_IM_Backup.ps1 -ORACLE_SID dbname -MV_NAME managed_volume_name -ORACLE_HOME oracle_home

.NOTES
To prepare to use this script complete the following steps:
1) Download the Rubrik Powershell module from Github or the Powershell Library.
  a) Install-Module Rubrik
  b) Import-Module Rubrik
  c) Get-Command -Module Rubrik
  d) Get-Command -Module Rubrik *RubrikDatabase*
  e) Get-Help Get-RubrikManagedVolume -ShowWindow
  f) Get-Help Start-RubrikManagedVolumeSnapshot -ShowWindow
  g) Get-Help Stop-RubrikManagedVolumeSnapshot -ShowWindow
2) Set a variable to your Rubrik API token or a credentials file for the Rubrik Powershell Module with your administrative Rubrik username and password.
  a) $cred = 'API TOKEN' or $cred = Get-Credential (Enter the Rubrik Administrator credentials to use for this script.)
  b) $cred | Export-Clixml C:\temp\RubrikCred.xml -Force
3) Create the Rubrik event log source: 
    From a Windows Powershell Administrative Shell run
        New-EventLog -Source Rubrik -LogName Application
4) Set Variables as necessary in script:
    a) Set Rubrik CDM address (Use Floating IP)
    b) Set appropriate credentials variable, $ApiTokenFile if using API Token, $CredentialFile if using User/passwork or 
    set $RubrikUser and $RubrikPasswork (Note: only use for tesing)
    c) Set the $Logdir path (make sure path exists)
5) Invoke this script to create managed volume.
This script requires:
- Powershell 5.1 (should work with 4+)
- Rubrik PowerShell Module
- Rubrik Credentials (credentials file or added to the script)
.LINK
https://build.rubrik.com/sdks/powershell/
https://github.com/rubrikinc/rubrik-sdk-for-powershell

Windows Events logged:
Event: Rubrik Connection Failed
Event Type: ERROR
Event ID: 55500

Event: Begin Snapshot Failed
Event Type: ERROR
Event ID: 55501

Event: End Snapshot Failed
Event Type: ERROR
Event ID: 55502

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

  # The Managed Volume name if different from the Database name
  [Parameter(Mandatory=$False,
  HelpMessage="Enter the Managed Volume name if different from the Database name.")]
  [string]$MV_NAME,

  # The Oracle Home
  [Parameter(Mandatory=$False,
  HelpMessage="Enter the ORACLE_HOME if not available in the Registry for this ORACLE_SID.")]
  [string]$ORACLE_HOME
)

#Load Rubrik module
Import-Module Rubrik

##########################################################################
# Edit Variables for you environment
# Set Rubrik variables
$RubrikAddress = '10.10.10.1'
$ApiTokenFile = 'C:\Scripts\RubrikAPI.xml' 
$CredentialFile = ''
$RubrikUser = ''
$RubrikPassword = ''
$logdir = 'C:\app\oraclesvc\tools\backup\backup_logs'
$logname = $Oracle_SID + '_rman'
# Number of days (negative number) of backup logs to retain
$logRetention = '-7'
# Archive log deletion policy Backed up N times
$ARCHIVELOG_NU = 1
# Number of days of backups to keep on the managed volume and in each Rubrik snapshot
$DB_BACKUP_RETENTION = 1
##########################################################################
# Create log file
$logdate = Get-Date -Format FileDateTime
$logfile = $logdir + '\' + $logname + $logdate + '.txt'

$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
# Begin logging
Start-Transcript -path $logfile -append


# Check to be we have an ORACLE_SID
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


# Set credentials
 if ($ApiTokenFile) {
        $credential = Import-Clixml $ApiTokenFile
    } elseif ($CredentialFile) {
        $credential = Import-Clixml $CredentialFile
    } else {
        $credential = New-Object pscredential ($RubrikUser,(ConvertTo-SecureString $RubrikPassword -AsPlainText -Force))
    } 
# If Managed Volume name wasn't set it to the Database name
if (!($MV_NAME)) { $MV_NAME = $ORACLE_SID}

# Connect to Rubrik
try {
 if ($ApiTokenFile) {
        Connect-Rubrik $RubrikAddress -token $credential
    } else {
        Connect-Rubrik $RubrikAddress -Credential $credential
    } 
} catch {
    $Message = "Rubrik Connection Failed" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nThere was an error connecting to the Rubrik Cluster."
    $Message = $Message + "`nContact Rubrik Support."

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55500 `
        -Message $Message
    Stop-Transcript
    exit 1

}

# Get MV Information
Write-Host ("Gathering managed volume details on $MV_NAME from Rubik...")
try{
$ManagedVolume = Get-RubrikManagedVolume -Name $MV_NAME
} catch {
    $Message = "Managed Volume Get Error" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nThere was an error retrieving the managed volume information from Rubrik Cluster."
    $Message = $Message + "`nManaged Volume return: $ManagedVolume"
    $Message = $Message + "`nContact Rubrik Support."

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55503 `
        -Message $Message
    Stop-Transcript
    exit 1
}



# Break out values in variables
$SHARE_TYPE = If($null -eq $ManagedVolume.shareType) {"NFS"} Else {$ManagedVolume.shareType}
$MV_ID = $ManagedVolume.id
$CHANNELS = $ManagedVolume.mainExport.channels

# Build the array of channel paths
$ChannelPaths = @()
foreach($CHANNEL in $CHANNELS) {
    $IP = $CHANNEL.ipAddress
    $EXPORT = $CHANNEL.mountPoint
    If($SHARE_TYPE -eq "NFS") {
        $ChannelPaths += "\\" + $IP + $EXPORT.replace("/","\")
    } Else {
        $ChannelPaths += "\\$IP\$EXPORT"
    }
}

# Send the Begin Snapshot API call
Write-Host "Starting Snapshot for $MV_NAME $MV_ID"
try {
$begin_snap_return = Start-RubrikManagedVolumeSnapshot $MV_ID
} catch {
    $Message = "Begin Snapshot Failed" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nThe Rubrik begin snapshot command failed"
    $Message = $Message + "`nSnapshot return: $begin_snap_return"
    $Message = $Message + "`nContact Rubrik Support."

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55501 `
        -Message $Message
    Stop-Transcript
    exit 1
}


# Run the RMAN database backup
Start-Sleep -Seconds 3
Write-Output ''
Write-Output 'Running RMAN Backup...'

# Build RMAN backup with channels for the managed volume
$SCRIPT = @"
set echo on;
show all;
configure controlfile autobackup on;
run {
set controlfile autobackup format for device type disk to '$($ChannelPaths[0])\%F';

"@

for ($i= 0; $i -lt $ChannelPaths.Length; $i++) {
    $CHANNELPATH = $ChannelPaths[$i]
    $SCRIPT += "allocate channel ch$i device type disk format '"+$CHANNELPATH+"\%U';`n"
}

$SCRIPT += @"
backup incremental level 1 for recover of copy with tag '$($ORACLE_SID)_incmrg' database;
recover copy of database with tag '$($ORACLE_SID)_incmrg' until time 'SYSDATE-$($DB_BACKUP_RETENTION)';
sql 'alter system archive log current';
backup archivelog all;
backup as copy current controlfile;

"@
for ($i= 0; $i -lt $ChannelPaths.Length; $i++) {
    $SCRIPT += "release channel ch$i;`n"
}

$SCRIPT += @"
}
allocate channel for maintenance device type disk;
crosscheck backup;
crosscheck copy;
delete noprompt expired copy;
delete noprompt expired backup;
delete noprompt obsolete recovery window of $($DB_BACKUP_RETENTION) days;
release channel;
"@ 

# Run the RMAN script and log results
$SCRIPT | rman nocatalog target=/ | Write-Host
$rman_return = $?

# Send the End Snapshot API call
try {
$end_snap_return = Stop-RubrikManagedVolumeSnapshot $MV_ID
} catch {
    $Message = "End Snapshot Failed" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nSnapshot return: $end_snap_return"
    $Message = $Message + "`nContact Rubrik Support."

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55502 `
        -Message $Message
    Stop-Transcript
    exit 1
}

if(-Not $rman_return) {
    $Message = "RMAN Backup Failed" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nThe RMAN backup command failed"
    $Message = $Message + "`nCheck the backup log: $logfile"

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55510 `
        -Message $Message
    Stop-Transcript
    exit 1
}

# After end snapshot delete backed up archive logs
$SCRIPT = @"
set echo on;
run {
  delete noprompt archivelog all backed up $ARCHIVELOG_NU times to device type disk;
}
quit;
"@ 

$SCRIPT | rman nocatalog target=/ | Write-Host
$rman_return = $?
if(-Not $rman_return) {
    $Message = "RMAN Archivelog Delete Failed" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nThe RMAN archive log deletion command failed"
    $Message = $Message + "`nCheck the backup log: $logfile"

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55511 `
        -Message $Message
    Stop-Transcript
    exit 1
}

# Check for Errors
$errors = Get-Content -path $logfile | Select-String "RMAN-[0-2]"
if ($errors) {
    $Message = "RMAN Script Error" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nThe RMAN backup contained errors"
    $Message = $Message + "`nCheck the backup log: $logfile"
    foreach($line in $errors){$Message = $Message + "`n" + $line}

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55512 `
        -Message $Message
    Stop-Transcript
    exit 1
}

# clean up log files
$searchPath = $logdir + '\*.txt'
Get-ChildItem  $searchPath | Where-Object LastWriteTime -LT (Get-Date).AddDays($logRetention) | Remove-Item

$Message = "RMAN Backup Completed" 
$Message = $Message + "`nDatabase SID: $ORACLE_SID"
$Message = $Message + "`nThe RMAN backup completed successfully."

Write-EventLog -LogName "Application" `
    -Source "Rubrik" `
    -EntryType "Information" `
    -EventId 55520 `
    -Message $Message

# End logging
Stop-Transcript
exit 0
