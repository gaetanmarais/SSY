# Initializing DataCore PowerShell Environment 
$bpKey = 'BaseProductKey'
$regKey = get-Item "HKLM:\Software\DataCore\Executive"
$strProductKey = $regKey.getValue($bpKey)
$regKey = get-Item "HKLM:\$strProductKey"
$installPath = $regKey.getValue('InstallPath')
Import-Module "$installPath\DataCore.Executive.Cmdlets.dll" -ErrorAction:Stop -Warningaction:SilentlyContinue

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
#$server = [Microsoft.VisualBasic.Interaction]::InputBox("Enter a DataCore server name or IP", "Server", "$env:computername")
$server = "$env:computername"
#$Credential = get-Credential

Connect-DcsServer -Server $server | Out-Null

Update-DcsServerPort -server $server -all| Out-Null


Get-DcsPort -Type iSCSI | where {$_.PortMode -imatch "Target"} | % {

    $iSCSIPORT=$_
    $WINNAME=$iSCSIPORT.IdInfo.Connectionname

    #$iqn = [Microsoft.VisualBasic.Interaction]::InputBox("Modify IQN of this Interface: " + $port.ExtendedCaption ,  $port.ExtendedCaption, $port.PortName)

    $IQN = "iqn.2000-08.com.datacore:"

    $IQN = (($iqn +  $WINNAME.Replace(" ", "-")).Replace("_", "-")).ToLower()


    Write-Host $iSCSIPORT $WINNAME $IQN

    Set-DcsPortProperties -Port $iSCSIPORT -NewName $WINNAME | Out-Null
    Set-DcsServerPortProperties -Port $iSCSIPORT -NodeName $IQN | Out-Null



    switch -Wildcard ($WINNAME) {

        {($_ -like "*_fe*") -or ($_ -like "*-fe*")}  {Set-DcsServerPortProperties -port $iSCSIPORT -PortRole FrontEnd | Out-Null}
        {($_ -like "*_mr*") -or ($_ -like "*-mr*")}  {Set-DcsServerPortProperties -port $iSCSIPORT -PortRole Mirror | Out-Null}
        "*mgmt" {Set-DcsServerPortProperties -port $iSCSIPORT -PortRole None | Out-Null}

    }
}



write-host "Connecting MR ports"

$SRV=Get-DcsServer | % {
    $SRV_=$_
    $INIT=Get-DcsPort -Type iSCSI -MachineType Servers -Machine $SRV_ | ? {$_.PhysicalName -eq "MSFT-05-1991"}
    $REMOTEIP=((Get-DcsPort -Type iSCSI -MachineType Servers | ? { ($_.ServerPortProperties.Role -eq "Mirror") -and ($_.HostId -ne $SRV_.ID) } ).ServerPortProperties.IScsiPortalsConfig|select Address)
    $REMOTEIP| % {
        $REMOTEIP_=$_.Address.Address -replace "[^0-9..]"
        $PS=New-PSSession -ComputerName $SRV_.Caption
        
        try {$RESULT=Invoke-Command -Session $PS { Test-NetConnection -Port 3260 -ComputerName $using:REMOTEIP_ } -ErrorAction Stop}
        catch {$_}

        if ( $RESULT.TcpTestSucceeded -eq $true ) { 
            #write-host $SRV_.Caption
            #write-host $REMOTEIP_
            $RESULT|select InterfaceAlias,RemoteAddress,TcpTestSucceeded,@{N="SourceAddress";E={$_.SourceAddress.IPAddress}}

            write-host "Server "$SRV_.caption" --- InitiatorPort "$INIT" --- InitiatorPortal " $RESULT.SourceAddress.IPAddress " ---- DestinationAddress" $RESULT.RemoteAddress.IPAddressToString
            Connect-DcsiSCSITarget -Server $SRV_ -InitiatorPort $INIT.Caption -InitiatorPortal $RESULT.SourceAddress.IPAddress -Address $RESULT.RemoteAddress.IPAddressToString -PortNumber 3260 -Password 11111111
            }
    }
}
