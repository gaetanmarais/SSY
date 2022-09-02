

# Get the installation path of SANsymphonyV
$bpKey = 'BaseProductKey'
$regKey = Get-Item "HKLM:\Software\DataCore\Executive"
$strProductKey = $regKey.getValue($bpKey)
$regKey = Get-Item "HKLM:\$strProductKey"
$installPath = $regKey.getValue('InstallPath')

Import-Module "$installPath\DataCore.Executive.Cmdlets.dll" -DisableNameChecking -ErrorAction Stop





function config_smtp {


    Write-Host "* SMTP server ["$SMTPSETTINGS.smtpserver"]: ?" -NoNewline
    $SMTPSERVER=read-host
    if ( !$SMTPSERVER ) { $SMTPSERVER = $SMTPSETTINGS.smtpserver}

    Write-Host "* Use SSL ["$SMTPSETTINGS.usessl"]: ?" -NoNewline
    $SMTPSSL=read-host
    if ( !$SMTPSSL ) { $SMTPSSL = $SMTPSETTINGS.usessl}
    Switch ( $SMTPSSL) 
        {
        YES { $SMTPSECURE = 1}
        Y   { $SMTPSECURE = 1}
        TRUE { $SMTPSECURE = 1 }
        1   { $SMTPSECURE = 1 }
        default   { $SMTPSECURE = 0}
        }


    Write-Host "* TCP port ["$SMTPSETTINGS.tcpport"]: ?" -NoNewline
    $SMTPPORT=read-host
    if ( !$SMTPPORT ) { $SMTPPORT = $SMTPSETTINGS.tcpport }

    Write-Host "* Sender email ["$SMTPSETTINGS.emailaddress"]: ?" -NoNewline
    $SMTPSENDER=read-host
    if ( !$SMTPSENDER ) { $SMTPSENDER = $SMTPSETTINGS.EmailAddress }
    Write-Host "* Username ["$SMTPSETTINGS.Username"]: ?" -NoNewline
    $SMTPUSER=read-host
    if ( !$SMTPUSER ) { $SMTPUSER = $SMTPSETTINGS.Username }
    Write-Host "* Password : ?" -NoNewline
    $SMTPPASSWORD=read-host


    Set-DcsSMTPSettings -SMTPServer $SMTPSERVER -UseSSL $SMTPSECURE -TCPPort $SMTPPORT -EmailAddress $SMTPSENDER -Username $SMTPUSER -Password $SMTPPASSWORD 


}








Connect-DcsServer
clear

$SMTPSETTINGS=Get-DcsSMTPSettings

    
    Write-Host "Configure SMTP Settings [Yes/No]: ?" -NoNewline
    if ( $(read-host) -in ("yes","y",1) ) { config_smtp}

    $DCSUSER=get-dcsuser | ? { $_.Caption -like 'administrat*' } | select -First 1
    $RECIPIENT=$DCSUSER.emailaddress
    if ( ($RECIPIENT -like "*@*") -eq $false ) {
        write-host "Configure "$DCSUser.caption" email adress"
        write-host " * Enter email adress for "$DCSUser.caption" : " -NoNewline
        $RECIPIENT=Read-Host
        Set-DcsUserProperties -User $DCSUser.caption -Email $RECIPIENT | Out-Null
    }


if ( Get-DcsTask -Task "MONITORING-EMAIL")  {
    Remove-DcsTask -Task "MONITORING-EMAIL" | Out-Null
}

Add-DcsTask -name "MONITORING-EMAIL"  | out-null
Add-DcsAction  -Task "MONITORING-EMAIL" -Recipient $RECIPIENT | out-null
Write-Host " * Do you want to monitor physical disks [ Yes/No ] : " -NoNewline
    if ( $(read-host) -in ("yes","y",1) ) { 
    Get-DcsMonitorTemplate | ? {$_.Description -like '*physical disks latency.'} | select -Unique TypeId | %{Add-DcsTrigger -Task MONITORING-EMAIL -TemplateTypeId $_.TypeId -MonitorState Healthy -Comparison ">"} | Out-Null

        }
    
Write-Host " * Do you want to monitor Pool Depletion [ Yes/No ] : " -NoNewline
    if ( $(read-host) -in ("yes","y",1) ) {
    Get-DcsMonitorTemplate | ? {$_.Monitortype -like '*PoolDepletionMonitor*'}| select -Unique TypeId | %{Add-DcsTrigger -Task MONITORING-EMAIL -TemplateTypeId $_.TypeId -MonitorState Healthy -Comparison ">"} |Out-Null
     }
Write-Host " * Do you want to monitor Server ports [ Yes/No ] : " -NoNewline
    if ( $(read-host) -in ("yes","y",1) ) {
    Get-DcsMonitorTemplate | ? {$_.Description -like '*busy*'}| select -Unique TypeId | %{Add-DcsTrigger -Task MONITORING-EMAIL -TemplateTypeId $_.TypeId -MonitorState Healthy -Comparison ">"} |Out-Null
        }    
     
Write-Host " * Do you want to monitor Virtual disk status [ Yes/No ] : " -NoNewline
    if ( $(read-host) -in ("yes","y",1) ) {
    Get-DcsMonitorTemplate | ? {$_.Description -like '*Monitors the data status of virtual disks.'}| select -Unique TypeId | %{Add-DcsTrigger -Task MONITORING-EMAIL -TemplateTypeId $_.TypeId -MonitorState Healthy -Comparison ">"} |Out-Null
     }



Write-Host " * Do you want to monitor DataCore servers [ Yes/No ] : " -NoNewline
    if ( $(read-host) -in ("yes","y",1) ) { 
        Get-DcsMonitorTemplate | ? { $_.description -like '*DataCore Server*' -and $_.description -notlike '*remote*'}| select -Unique TypeId | %{Add-DcsTrigger -Task MONITORING-EMAIL -TemplateTypeId $_.TypeId -MonitorState Healthy -Comparison ">"} |Out-Null
          
    }



