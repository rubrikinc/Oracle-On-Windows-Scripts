<#

.SYNOPSIS

This PowerShell script will take a RMAN backup of an Oracle database to a Rubrik SLA Manged Volume

.DESCRIPTION

Use the DATABASE flag for a database only backup, the LOG flag for an archivelog only backup. If no backup type flag (DATABASE or LOG)
is supplied both a database and archive log backup will be done. If doing a combined database and archived log backup, you 
should be only using a single SLA MV and the $arc_dirs variable should be commented out. 

Note this script does not delete archived logs from the host after they are backed up. This should be done in 
a post script added to the SLA Managed Volume.

The ORACLE_HOME will can be determined from the registry settings as long as there is a registry key set under 
HKEY_LOCAL_MACHINE\SOFTWARE\ORACLE\KEY_(ora home name). If the ORACLE_HOME cannot be determined from the registry
an ORACLE_HOME must be supplied.

WARNING: THIS CODE IS PROVIDED ON A BEST EFFORT BASIS AND IS NOT IN ANY WAY OFFICIALLY SUPPORTED 
OR SANCTIONED BY RUBRIK. THE CODE IN THIS REPOSITORY IS PROVIDED AS-IS AND THE AUTHOR ACCEPTS 
NO LIABILITY FOR DAMAGES RESULTING FROM ITS USE.

CODE HERE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
THE AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.EXAMPLE

powershell C:\Scripts\Rubrik_Oracle_SLAMV_Backup.ps1 -DATABASE -FULL 


.NOTES
To prepare to use this script complete the following steps:

1) Create the Rubrik event log source: 
    From a Windows Powershell Administrative Shell run
        New-EventLog -Source Rubrik -LogName Application
4) Set Variables as necessary in script:
    a) Set Oracle SID
    b) Set the mount paths for the database SLA MV paths and the archived log SLA MV (If using 2 SLA MVs)
    c) Set the $Logdir path (make sure path exists)

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
  
  # Set if DB only backup
  [Parameter(Mandatory=$False,
  HelpMessage="Use the DATABASE flag for a database only backup.")]
  [switch]$DATABASE,

  # Set if Archive Log only backup
  [Parameter(Mandatory=$False,
  HelpMessage="Use the LOG flag for an archive log only backup.")]
  [switch]$LOG,

  # Set to do a RMAN full backupset backup instead of the Incremental Merge
  [Parameter(Mandatory=$False,
  HelpMessage="Use the FULL flag to take a RMAN full backupset backupset instead of the Incremental Merge Backup.")]
  [switch]$FULL
)


###################################################
# Edit Variables for you environment
# Set Rubrik variables
###################################################
###################################################
# Oracle SID
$ORACLE_SID = 'db_name'
# Oracle HOME - OPTIONAL, if not set the script will attempt to get that from the registry
$ORACLE_HOME = ''
# DB SLA MV Export Paths as a power shell array, add all the channels to the array
$db_dirs = @('C:\Rubrik\dbname\db_c0','C:\Rubrik\dbname\db_c1')
# Archive Log SLA MV Export Paths as a power shell array, add all the channels to the array, comment out if only using a DB SLA MV
$arc_dirs = @('C:\Rubrik\dbname\log_c0')
# Log directory - This must exist for the script to run
$logdir = 'C:\Rubrik\logs'
# Log name format
$logname = $Oracle_SID + '_slamv'
# Number of days (negative number) of backup script logs to retain
$logRetention = -7
# Number of days of backups to keep on the managed volume and in each Rubrik snapshot
$DB_BACKUP_RETENTION = 1
# Section Size - Only used when FULL is set. This is used to break up large bigfile datafiles
$SECTION_SIZE = '100G'
###################################################


###################################################
# Create log file
###################################################
$logdate = Get-Date -Format FileDateTime
$logdate = $logdate -replace ".{4}$"
if ($LOG) {
    $logname = $logname + '_LOG_'
} else {
    $logname = $logname + '_DB_'
}
$logfile = $logdir + '\' + $logname + $logdate + '.txt'

###################################################
# Start logging
###################################################
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
    # Find the ORACLE_HOME
    $ORACLE_HOME = (Get-ItemProperty -Path "Registry::$((Get-ChildItem -Path HKLM:\SOFTWARE\ORACLE | Where-Object {$_.Property -eq "ORACLE_HOME"}).Name)").ORACLE_HOME
    IF ($null -eq $ORACLE_HOME) {
        Write-Host -ForegroundColor Red "ORACLE_HOME not found in the registry. Please provide ORACLE_HOME when running this script."
        exit 1
    } elseif ($ORACLE_HOME.Count -gt 1) {
        Write-Host -ForegroundColor Red "Multiple ORACLE_HOMEs ($ORACLE_HOME) found in the registry. Please provide correct ORACLE_HOME when running this script."
        exit 1
    }
} 

# Set the environment for the database
Write-Host  -ForegroundColor Green "Using $ORACLE_HOME to set the environment variables for database $ORACLE_SID."
$Env:ORACLE_SID=$ORACLE_SID
$Env:ORACLE_HOME=$ORACLE_HOME
$env:NLS_DATE_FORMAT="MM/DD/YY HH24:MI:SS"


Write-Output ''

if ($DATABASE) {
    Write-Host "Backup type is database only backup"
} elseif ($LOG) {
    Write-Host "Backup type is archive log backup"
} else {
    Write-Host "Backup type is combined database and archive log backup"
}


######################################################################
# Backup database if a database backup or a combined backup
######################################################################
if (-Not $LOG) {
    Write-Output 'Running RMAN Database Backup...'

    # Build RMAN backup with channels for the managed volume
    $SCRIPT = @"
set echo on;
show all;
configure controlfile autobackup on;
run {
set controlfile autobackup format for device type disk to '$($db_dirs[0])\%F';`n
"@

for ($i= 0; $i -lt $db_dirs.count ; $i++) {
    $SCRIPT += "allocate channel ch$i device type disk format '"+$db_dirs[$i]+"\%U';`n"
}
if ($FULL) {
$SCRIPT += @"
backup as backupset filesperset 1 section size $($SECTION_SIZE) database tag '$($ORACLE_SID)_incmrg';
backup as copy current controlfile;`n
"@
} else {
$SCRIPT += @"
backup incremental level 1 for recover of copy with tag '$($ORACLE_SID)_incmrg' database;
recover copy of database with tag '$($ORACLE_SID)_incmrg' until time 'SYSDATE-$($DB_BACKUP_RETENTION)';
backup as copy current controlfile;`n
"@
}
for ($i= 0; $i -lt $db_dirs.count; $i++) {
    $SCRIPT += "release channel ch$i;`n"
}

$SCRIPT += @"
    }
"@ 

    # Run the RMAN script and log results
    try{
        $SCRIPT | rman nocatalog target=/ | Write-Host
    } catch {
        $Message = "Error Running RMAN" 
        $Message = $Message + "`nDatabase SID: $ORACLE_SID"
        $Message = $Message + "`nThere was an error running the RMAN command for the database backup."
        Write-Host $Message

        Write-EventLog -LogName "Application" `
            -Source "Rubrik" `
            -EntryType "Error" `
            -EventId 55510 `
            -Message $Message
        Stop-Transcript
        exit 0
    }

}

######################################################################
# Backup archived logs if an archive log backup or a combined backup
######################################################################

if ($LOG -Or (-Not $DATABASE)) {
    Write-Output 'Running RMAN Archive Log Backup...'
    # If there is no archive log directorys set, send the archived logs to the database directories
    if (-Not $arc_dirs) {
        $log_backup_dirs = $db_dirs
    } else {
        $log_backup_dirs = $arc_dirs
    }

    # Build RMAN backup with channels for the managed volume
    $SCRIPT = @"
set echo on;
configure controlfile autobackup on;
run {
set controlfile autobackup format for device type disk to '$($log_backup_dirs[0])\%F';`n
"@

for ($i= 0; $i -lt $db_dirs.count ; $i++) {
    $SCRIPT += "allocate channel ch$i device type disk format '"+$log_backup_dirs[$i]+"\%U';`n"
}

$SCRIPT += @"
sql 'alter system archive log current';
backup archivelog all;`n
"@
for ($i= 0; $i -lt $log_backup_dirs.count; $i++) {
    $SCRIPT += "release channel ch$i;`n"
}

$SCRIPT += @"
    }  
"@ 

    # Run the RMAN script and log results
    try{
        $SCRIPT | rman nocatalog target=/ | Write-Host
        $rman_return = $?
    } catch {
        $Message = "Error Running RMAN" 
        $Message = $Message + "`nDatabase SID: $ORACLE_SID"
        $Message = $Message + "`nThe RMAN command failed running the archive log backup."
        Write-Host $Message

        Write-EventLog -LogName "Application" `
            -Source "Rubrik" `
            -EntryType "Error" `
            -EventId 55510 `
            -Message $Message
        Stop-Transcript
        exit 0
    }
}

###################################################
# Run the RMAN maintenance to clean up old backups on the current snapshot
###################################################
Write-Output 'Running RMAN mantainance commands to delete obsolete backups...'
# Build RMAN backup with channels for the managed volume
$SCRIPT = @"
set echo on;
allocate channel for maintenance device type disk;
"@

    for ($i= 0; $i -lt $db_dirs.count ; $i++) {
        $SCRIPT += "catalog start with '"+$db_dirs[$i]+"' noprompt;"
    }
    if ($arc_dirs) {
        for ($i= 0; $i -lt $arc_dirs.count ; $i++) {
            $SCRIPT += "catalog start with '"+$arc_dirs[$i]+"' noprompt;"
        }
    }

$SCRIPT += @"
crosscheck backup;
crosscheck copy;
delete noprompt expired copy;
delete noprompt expired backup;
delete noprompt obsolete recovery window of $($DB_BACKUP_RETENTION) days;
release channel;
"@ 


# Run the RMAN maintenance script and log results
try{
    $SCRIPT | rman nocatalog target=/ | Write-Host
    $rman_return = $?
} catch {
    $Message = "Error Running RMAN" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nThere was an error running the RMAN maintenance command."
    Write-Host $Message

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55510 `
        -Message $Message
    Stop-Transcript
    exit 0
}

###################################################
# Check the log files for errors
###################################################
Write-Host "Parsing the log file for errors..."
# Find the RMAN-{0-2] errors in the log
$errors = Get-Content -path $logfile | Select-String "RMAN-[0-2]"
# Remove normal errors 
# Error ignored is "RMAN-08138: warning: archived log not deleted - must create more backups" 
# Repeat next line for additional errors to ignore
$errors = $errors | Select-String -notmatch "RMAN-08138"
if ($errors) {
    $Message = "RMAN Script Error" 
    $Message = $Message + "`nDatabase SID: $ORACLE_SID"
    $Message = $Message + "`nThe RMAN backup log contained errors"
    $Message = $Message + "`nCheck the backup log: $logfile"
    foreach($line in $errors){$Message = $Message + "`n" + $line}
    Write-Host $Message

    Write-EventLog -LogName "Application" `
        -Source "Rubrik" `
        -EntryType "Error" `
        -EventId 55512 `
        -Message $Message
    Stop-Transcript
    exit 0
}
Write-Host "The log file looks good!"

###################################################
# Clean up old script logs
###################################################
Write-Output "Cleaning up local script logs older than $LogRetention"
$searchPath = $logdir + '\*.txt'
Get-ChildItem  $searchPath | Where-Object LastWriteTime -LT (Get-Date).AddDays($logRetention) | Remove-Item

###################################################
# Finish up log and send success event
###################################################
$Message = "RMAN Backup Completed" 
$Message = $Message + "`nDatabase SID: $ORACLE_SID"
$Message = $Message + "`nThe RMAN backup completed successfully."

Write-EventLog -LogName "Application" `
    -Source "Rubrik" `
    -EntryType "Information" `
    -EventId 55520 `
    -Message $Message
Write-Host $Message

# End logging
Stop-Transcript
exit 0 
