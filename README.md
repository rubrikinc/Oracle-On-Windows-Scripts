# Oracle-On-Windows-Scripts
Windows PowerShell scripts for backing up Oracle databases running on Windows to Rubrik Managed Volumes


Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Rubrik. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

CODE HERE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# :hammer: Requirements
## Python 3.7 installation instructions for OEL/RHEL linux.
------------------------------------------------------------
As root:

```
yum install gcc openssl-devel bzip2-devel libffi-devel
cd /usr/src
wget https://www.python.org/ftp/python/3.7.6/Python-3.7.6.tgz
tar xzf Python-3.7.6.tgz
cd Python-3.7.6
./configure --enable-optimizations
make altinstall
rm /usr/src/Python-3.7.6.tgz
```
Now check python:

```
python3.7 -V
```
Python 3.7 is now installed.


## Download the Rubrik Oracle scripts
------------------------------------------------
Download the Rubrik Oracle Tools Repository
```
git clone https://github.com/pcrouleur/rubrik_oracle_tools.git
```


## Create a python virtual environment to Run the scripts (optional)
------------------------------------------------------------------------------------
As the user (oracle):
```
cd to where you want the env
cd /home/oracle/rubrik_oracle_tools/
python3.7 -m venv venv37
```

Activate the environment (This can be added to your .bash_profile):
```
source venv37/bin/activate
```

Upgrade pip (optional):
```
pip install --upgrade pip
```


## Install the Rubrik Oracle Tools
------------------------------------------------------------------------------------
cd to the Rubrik Oracle Tools directory
```
cd /home/oracle/rubrik_oracle_tools/
```
If installing into a virtual environment, make sure that is activated:
```
source venv37/bin/activate
```
Install the module with setup tools:
```
pip install --editable .
```


## 	:gear: Configure the connection parameters
----------------------------------------------------
Edit the config.json file with the Rubrik CDM connection parameters or set those parameters as environmental variable (see instructions at build.rubrik.com)
You must provide the Rubrik CDM address or an IP in the cluster and either an API token or a user/password.

#### Example config.json file:
```
{
  "rubrik_cdm_node_ip": "10.1.1.20",
  "rubrik_cdm_token": "",
  "rubrik_cdm_username": "oraclesvc",
  "rubrik_cdm_password": "RubrikRules"
}
```
You should probably restrict access to the config.json file
```
chmod 600 config.json
```

## :mag: Command Summary:
----------------------------------------------------
The following will connect to Rubrik, run using the Rubrik Backup Service and can be run from any host:
```
rubrik_oracle_backup_info - Gets backup information for a database or all databases.
rubrik_oracle_mount_info - Gets information for mounts on a host.
rubrik_oracle_snapshot - Initiates a Rubrik Oracle database backup.
rubrik_oracle_log_backup - Initiates a Rubrik Oracle archive log backup.
rubrik_oracle_backup_mount - Mounts RMAN backups.
rubrik_oracle_db_mount - Live mounts an Oracle database.
rubrik_oracle_db_clone - Clones an Oracle database.
rubrik_oracle_unmount - Removes a Rubrik mount. Can be a live mounted database or RMAN Backups.
```
The follow will connect to Rubrik but must also connect to the local Oracle instance. They must be run on the target host:
```
rubrik_oracle_backup_clone - Duplicates/clones an Oracle databae using RMAN and the RMAN backups from Rubrik. Allow database refresh.
rubrik_oracle_backup_mount_clone - This will do a live mount from the RMAN backups and allow you to change the name prior to the clone.
rubrik_oracle_db_mount_clone - This will do a Rubrik live mount and then change the name after the mount completes.
rubrik_oracle_clone_unmount - Removes a live mount when the name has been changed.
```


## :mag: Available commands:
----------------------------------------------------
#### rubrik_oracle_backup_info
```
rubrik_oracle_backup_info --help
Usage: rubrik_oracle_backup_info [OPTIONS]
