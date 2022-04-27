

Basic Usage

SLA Managed volume setup steps

1) Check the version of Powershell
    Type $PSVersionTable in a PowerShell window. 
    Version should be 5.1 or greater
    If not install Windows Management Framework 5.1 or  greater

2) Install the Rubrik PowerShell Module
    Available at https://build.rubrik.com/sdks/powershell/
    AFrom a Windows Powershell Administrator Shell run:
        Install-Module Rubrik
    Test with the following:
        Import-Module Rubrik
        Get-Command -Module Rubrik

3) Create the Rubrik event log source: 
    From a Windows Powershell Administrator Shell run:
        New-EventLog -Source Rubrik -LogName Application

4) Create Directories for SLA managed volume mounts, scripts, and script logs
    Example:
    Create C:\Rubrik\scripts
    Create C:\Rubrik\logs
    Create C:\Rubrik\dbname

5) Create API token file 
    Example:
        $cred = 'API TOKEN'
        $cred | Export-Clixml C:\Rubrik\scripts\RubrikCred.xml -Force

6) Set variables in script
    Example of what needs to be configured:
        # Address of the Rubrik CDM cluster (IP or FQDN)
        $RubrikAddress = '10.1.1.11'
        # Location of API key file (optional, can use CredentialFile or RubrikUser/RubrikPassword instead)
        $ApiTokenFile = 'C:\Rubrik\scripts\RubrikCred.xml'
        # Log directory - This must exist for the script to run
        $logdir = 'C:\Rubrik\logs'

7) Create SLA managed volume
