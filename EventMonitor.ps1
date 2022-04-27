$EventId = 55500,55501,55502,55503,55510,55511,55512

$A = Get-WinEvent -MaxEvents 1  -FilterHashTable @{Logname = "Application" ; ID = $EventId}
$Message = $A.Message
$EventID = $A.Id
$MachineName = $A.MachineName
$Source = $A.ProviderName


$EmailFrom = "hostname@rubrik.com"
$EmailTo = "oracle@rubrik.com"
$Subject ="Alert From $MachineName"
$Body = "EventID: $EventID`nSource: $Source`nMachineName: $MachineName `nMessage: $Message"
$SMTPServer = "mgmt-mx.rubrikdemo.com"
$SMTPPort = 25
Send-MailMessage -To $EmailTo -From $EmailFrom -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort