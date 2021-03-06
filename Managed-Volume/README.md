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

## 4) Create Directories for the scripts and script logs

> Example, create the following directories:<br>
C:\Rubrik\scripts<br>
C:\Rubrik\logs<br>


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

## 7) Create Managed Volume 

> Name: `dbname` <br>
Provisioned Size (GB): `4X allocated  DB size for start` <br>
Subnet (Optional): `Used if multiple VLANs in use` <br>
Protocol: `NFS or SMB` <br>
If using SMB:
Domain: `Active Directory Domain` <br>
Username: `Active Directory Username (oracle)` <br>
or <br>
Group: `Active Directory Domain` <br>
Application Tag: `Oracle Incremental Merge` <br>
Client Name Patterns (Optional): `Hostname or IP of Oracle host` <br>
Number of Channels: `If not already known use 1 channel per 250G of database size (Note SE oracle only supports 1)` <br>

## 8) Test the script
> From a PowerShell window or a PowerShell ISE window run:<br>
`.\rubrik_oracle_mv_backup.ps1 -ORACLE_SID dbname -MV_NAME managed_volume_name`

## 9) Add the script to the Windows Scheduler (or your scheduler of choice)
> The action will be start a program:<br>
`powershell rubrik_oracle_mv_backup.ps1 -ORACLE_SID dbname -MV_NAME managed_volume_name`