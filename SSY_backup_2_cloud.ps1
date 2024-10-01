###################################################################################################################################
###################################################################################################################################
####
#### SANSYMPHONY - backup conf to cloud
####
####
#### Author     : Gaetan MARAIS
#### Date       : 2024/09/19
####
####
#### Version    : 1.0
####              
####
####
####
####
###################################################################################################################################
###################################################################################################################################

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

# Get the installation path of SANsymphony-V and load cmdlet library

$bpKey = 'BaseProductKey'
$regKey = Get-Item "HKLM:\Software\DataCore\Executive"
$regTMY = Get-Item "HKLM:\SOFTWARE\DataCore\Telemetry\Plugins\BundleCollector"
$strProductKey = $regKey.getValue($bpKey)
$regKey = Get-Item "HKLM:\$strProductKey"
$installPath = $regKey.getValue('InstallPath')
$TMYinstallPath = $regTMY.GetValue('InstallPath')
$server = $env:COMPUTERNAME


Import-Module "$installPath\DataCore.Executive.Cmdlets.dll" -DisableNameChecking -ErrorAction Stop


#Variables
################################################
$endpoint="https://production.swarm.datacore.paris"
$bucket="sansymphony-backup"
$logs=$installPath+"\ssy-backup.log"
$timeout=3

Connect-DcsServer | out-null


Backup-DcsConfiguration | Out-Null

while ( (Get-DcsLogMessage -StartTime (Get-Date).AddMinutes(-$timeout) | ? {$_.MessageTExt -like "Successfully preserved the configuration on server*"}).count -ne (Get-DcsServer).count ) {
    sleep 5
}

sleep 30


Get-DcsServer| sort | % {

    $DCSserver = $_.caption
    $Result=Get-DcsBackUpFolder -Server $DCSserver
    $DCSbackupfolder="\\"+$DCSserver+"\"+$Result.replace(":","`$")
    $DCSBackupName=(Get-ChildItem -Path $DCSbackupfolder | Where-Object { $_.LastWriteTime -gt (get-date).Addminutes(-$timeout)}| sort -Descending -Property LastWritetime | select -First 1).Name
    $DCSBackupFullName=$DCSbackupfolder+"\"+$DCSBackupName
    $DCSBackupFullName| out-file -FilePath $logs -Append
    try {  $Upload=(Invoke-WebRequest -Uri "$endpoint/$bucket/$DCSBackupName" -InFile $DCSBackupFullName -Method "POST" -ContentType "application/x-zip-compressed" -UseBasicParsing -ErrorAction SilentlyContinue)}
    catch { $Error[0].Exception.Message | out-file -FilePath $logs -Append }
    finally { $Upload.RawContent | out-file -FilePath $logs -Append }
  
"======================================================================="| out-file -FilePath $logs -Append
"======================================================================="| out-file -FilePath $logs -Append
}
