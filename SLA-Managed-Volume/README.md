WARNING: THIS CODE IS PROVIDED ON A BEST EFFORT BASIS AND IS NOT IN ANY WAY OFFICIALLY SUPPORTED OR SANCTIONED BY RUBRIK. THE CODE IN THIS REPOSITORY IS PROVIDED AS-IS AND THE AUTHOR ACCEPTS NO LIABILITY FOR DAMAGES RESULTING FROM ITS USE.

CODE HERE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Basic Usage

SLA Managed volume setup steps

## 1) Check the version of Powershell

> In a PowerShell window, run:.<br>
`$PSVersionTable`<br>
Version should be 5.1 or greater<br>
If not install Windows Management Framework 5.1 or  greater

## 2) Install the Rubrik PowerShell Module<br>

> Available at https://build.rubrik.com/sdks/powershell/ <br>
From a Windows Powershell Administrator Shell run:<br>
`Install-Module Rubrik`<br>
If unable to connect to the Powershell Gallery to download the module, follow the instructions at https://build.rubrik.com/sdks/powershell/ to manually download and install the module. 

> Test with the following:<br>
`Import-Module Rubrik`<br>
`Get-Command -Module Rubrik`
You should be able to import the module and see the available commands.

## 3) Create the Rubrik event log source: 

> From a Windows Powershell Administrator Shell run:<br>
`New-EventLog -Source Rubrik -LogName Application`

## 4) Create Directories for SLA managed volume mounts, scripts, and script logs

> Example, create the following directories:<br>
C:\Rubrik\scripts<br>
C:\Rubrik\logs<br>
C:\Rubrik\dbname<br>

## 5) Create API token file 

> Example:<br>
    `$cred = 'API TOKEN'`<br>
    `$cred | Export-Clixml C:\Rubrik\scripts\RubrikCred.xml -Force`

## 6) Set variables in script

> Example of what needs to be configured:<br>
    # Address of the Rubrik CDM cluster (IP or FQDN)<br>
    `$RubrikAddress = '10.1.1.11'`<br>
    # Location of API key file (optional, can use CredentialFile or RubrikUser/RubrikPassword instead)<br>
    `$ApiTokenFile = 'C:\Rubrik\scripts\RubrikCred.xml'`<br>
    # Log directory - This must exist for the script to run<br>
    `$logdir = 'C:\Rubrik\logs'`<br>

## 7) Create SLA managed volume - Select type of backup

## A) Archive log backup with database backup (typically 1 per day)

#### Pane 1

> Name: `dbname` <br>
Provisioned Size (GB): `4X allocated  DB size for start` <br>
Subnet (Optional): `Used if multiple VLANs in use` <br>
Number of Channels: `If not already known use 1 channel per 250G of database size (Note SE oracle only supports 1)` <br>
IP or Hostname: `Oracle host with database and Rubrik Connector installed`

#### Pane 2
> Domain: `Your Active Directory Domain` <br>
Username: `The Active Directory user running Oracle. If running as a system service you can use hostname$ if the host has been added to the Active Directory` <br>
Active Directory Groups (Optional): `Can be used instead of the username` <br>
Mount point paths on the host: <br>
`C:\Rubrik\dbname\db_c0` <br>
`C:\Rubrik\dbname\db_c1` <br>
`C:\Rubrik\dbname\db_c2` <br>
`C:\Rubrik\dbname\db_c3` 
    
#### Pane 3
> Command  to run on the host: <br> 
`powershell C:\Rubrik\scripts\rubrik_oracle_SLAMV_backup.ps1 -ORACLE_SID dbname -MV_NAME mvname` <br>
Enable pre-backup and post-backup commands: `Check` <br>

> Command to run on successful backup: <br>
`powershell C:\Rubrik\scripts\rubrik_oracle_SLAMV_arc_log_delete.ps1 -ORACLE_SID dbname` <br>
Timeout: <br>
`Set to longer than log delete will take, example 600` <br>

## B) Database backup with higher frequency archive log backups. This requires 2 SLA managed volumes and 2 SLA Domain Policies. One for the database backup and one for the archive log backups.

### a) DB SLA Managed Volume
#### Pane 1

> Name: `dbname_db` <br>
Provisioned Size (GB): `4X allocated  DB size for start` <br>
Subnet (Optional): `Used if multiple VLANs in use` <br>
Number of Channels: `If not already known use 1 channel per 250G of database size (Note SE oracle only supports 1)` <br>
IP or Hostname: `Oracle host with database and Rubrik Connector installed`

#### Pane 2
> Domain: `Your Active Directory Domain` <br>
Username: `The Active Directory user running Oracle. If running as a system service you can use hostname$ if the host has been added to the Active Directory` <br>
Active Directory Groups (Optional): `Can be used instead of the username` <br>
Mount point paths on the host: <br>
`C:\Rubrik\dbname\db_c0` <br>
`C:\Rubrik\dbname\db_c1` <br>
`C:\Rubrik\dbname\db_c2` <br>
`C:\Rubrik\dbname\db_c3` 
    
#### Pane 3
> Command  to run on the host: <br> 
`powershell C:\Rubrik\scripts\rubrik_oracle_SLAMV_backup.ps1 -ORACLE_SID dbname -MV_NAME mvname -DATABASE` <br>
Enable pre-backup and post-backup commands: `Unchecked` <br>

### b) Archive Log SLA Managed Volume
#### Pane 1

> Name: `dbname_log` <br>
Provisioned Size (GB): `4X allocated  DB size for start` <br>
Subnet (Optional): `Used if multiple VLANs in use` <br>
Number of Channels: `If not already known use 1 channel per 250G of database size (Note SE oracle only supports 1)` <br>
IP or Hostname: `Oracle host with database and Rubrik Connector installed`

#### Pane 2
> Domain: `You Active Directory Domain` <br>
Username: `The Active Directory user running Oracle. If running as a system service you can use hostname$ if the host has been added to the Active Directory` <br>
Active Directory Groups (Optional): `Can be used instead of the username` <br>
Mount point paths on the host: <br>
`C:\Rubrik\dbname\log_c0` <br>
`C:\Rubrik\dbname\log_c1` <br>
`C:\Rubrik\dbname\log_c2` <br>
`C:\Rubrik\dbname\log_c3` 
       
#### Pane 3
> Command  to run on the host: <br> 
`powershell C:\Rubrik\scripts\rubrik_oracle_SLAMV_backup.ps1 -ORACLE_SID dbname -MV_NAME mvname -LOG` <br>
Enable pre-backup and post-backup commands: `Check` <br>

> Command to run on successful backup: <br>
`powershell C:\Rubrik\scripts\rubrik_oracle_SLAMV_arc_log_delete.ps1 -ORACLE_SID dbname` <br>
Timeout: <br>
`Set to longer than log delete will take, example 600` <br>

## B) Cold backup of database not in archive log mode (typically 1 per day)

#### Pane 1

> Name: `dbname` <br>
Provisioned Size (GB): `4X allocated  DB size for start` <br>
Subnet (Optional): `Used if multiple VLANs in use` <br>
Number of Channels: `If not already known use 1 channel per 250G of database size (Note SE oracle only supports 1)` <br>
IP or Hostname: `Oracle host with database and Rubrik Connector installed`

#### Pane 2
> Domain: `Your Active Directory Domain` <br>
Username: `The Active Directory user running Oracle. If running as a system service you can use hostname$ if the host has been added to the Active Directory` <br>
Active Directory Groups (Optional): `Can be used instead of the username` <br>
Mount point paths on the host: <br>
`C:\Rubrik\dbname\db_c0` <br>
`C:\Rubrik\dbname\db_c1` <br>
`C:\Rubrik\dbname\db_c2` <br>
`C:\Rubrik\dbname\db_c3` 
    
#### Pane 3
> Command  to run on the host: <br> 
`powershell C:\Rubrik\scripts\rubrik_oracle_SLAMV_backup.ps1 -ORACLE_SID dbname -MV_NAME mvname -DATABASE` <br>
Enable pre-backup and post-backup commands: `Check` <br>

> Command to run before backup: <br>
`powershell C:\Rubrik\scripts\rubrik_oracle_cold_prepost.ps1 -ORACLE_SID dbname -MOUNT` <br>
Timeout:<br>
`Set to longer than shutdown immediate, startup mount will take, example 300` <br>
Cancel backup if pre-backup command fails: `Checked` <br>

> Command to run on successful backup: <br>
`powershell C:\Rubrik\scripts\rubrik_oracle_cold_prepost.ps1 -ORACLE_SID dbname -OPEN` <br>
Timeout: <br>
`Set to longer than the database open will take, example 300` <br>

## 8) Apply appropriate SLA Domain Policy to the SLA Managed Volume

### A) Database backup with include archive log backup
> Use 1 SLA Domain Policy with backup frequency set - typically 1 per day

### B) Database backup with seperate archive log backup
> Use 1 SLA Domain Policy for the database SLA managed volume with backup frequency set - typically 1 per day. 

>Use a second SLA Domain Policy for the archive log SLA managed volume with the archive log backup frequency set - Anywhere from 15 minutes and up. 

### A) Cold Database backup
> Use 1 SLA Domain Policy with backup frequency set - typically 1 per day