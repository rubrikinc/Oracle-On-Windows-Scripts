# Oracle-On-Windows-Scripts
Windows PowerShell scripts for backing up Oracle databases running on Windows to Rubrik Managed Volumes

There are 2 sets of scripts, one for SLA Managed Volumes and one for standard Managed Volumes. These are example scripts and can be customized as necessary. 

WARNING: THIS CODE IS PROVIDED ON A BEST EFFORT BASIS AND IS NOT IN ANY WAY OFFICIALLY SUPPORTED OR SANCTIONED BY RUBRIK. THE CODE IN THIS REPOSITORY IS PROVIDED AS-IS AND THE AUTHOR ACCEPTS NO LIABILITY FOR DAMAGES RESULTING FROM ITS USE.

CODE HERE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# :hammer: Requirements
## Both the SLA Managed Volume and Managed Volume script require the following
------------------------------------------------------------
- Powershell 5.1 or greater (Installed with Windows Management Framework 5.1 or greater)
- Rubrik PowerShell Module
- Rubrik Credentials (API Token/credentials file or added to the script)
- Local Directory for script logs