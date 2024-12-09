###################################################################################################################################
###################################################################################################################################
####
#### SANSYMPHONY - This script is used in HyperV environnement to setup vSwitches and vNics
####
####
#### Author     : Gaetan MARAIS
#### Date v0    : 2024/03/19
####
####
#### Version    : 2.0
####            : 2.1 - Add VLAN   24/12/09
####              
####
#### 
####
####
###################################################################################################################################
###################################################################################################################################


clear


#Variables

$NTPSERVERS="0.fr.pool.ntp.org 1.fr.pool.ntp.org"
$TIMEZONE="Romance Standard Time"




#Functions

function seplines {
write-host ""
write-host "--------------------------------------------------------------------------------------------------------------"
}


function write-color ($color,$message,$option) {
    if ( $option -eq "NL" ) {   write-host -ForegroundColor $color "$message" -NoNewline }
    else { write-host -ForegroundColor $color "$message" }
}

function setshortname {
    seplines
    write-host "Hostname is " -NoNewline
    write-color green $env:COMPUTERNAME
    write-host "Short name will be used as a trigram to create switches, interfaces, ...."
    write-host "Please enter Short name for " -NoNewline
    write-color green $env:COMPUTERNAME NL
    write-host " (5 characters max) [" -NoNewline
    write-color green $(($env:COMPUTERNAME).Substring(0,3)) NL
    write-host "] : " -NoNewline
    $ANSWER = read-host
    
    if ( ! $ANSWER ) {$ANSWER=$(($env:COMPUTERNAME).Substring(0,3))}
    $global:SHORTNAME=$ANSWER
}

function setpagefile {
    seplines
    Write-Host "Do you want to set the pagefile [y/" -NoNewline
    write-color green "N" NL 
    write-host "] : " -NoNewline
    $ANSWER=Read-Host 
    if ( $ANSWER -eq "y" ) {
    write-host "This server run $((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb)Gb of memory"
    Write-Host "Below the detail of all volumes available"
    (Get-Volume |?{$_.DriveType -eq "Fixed" -and $_.DriveLetter} | Select-Object DriveLetter,FileSystemType,@{N="Size Gb";E={[math]::round($_.Size/1Gb)}},@{N="Available Gb";E={[math]::round($_.SizeRemaining/1Gb)}})|FT


    write-host "How many Mb do you want to set for the pagefile [" -NoNewline
    write-color green 4096 NL
    write-host "] MB: " -NoNewline
    $SWAPSIZE=read-host 
    if ( ! $SWAPSIZE ) {$SWAPSIZE=4096}

    write-host "In which volume do you want to store the pagefile [" -NoNewline
    write-color green C NL
    write-host "] : " -NoNewline
    $SWAPLOCATION=read-host
    if ( ! $SWAPLOCATION ) { $SWAPLOCATION = "C"}

    $pagefile = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
    $pagefile.AutomaticManagedPagefile = $false
    $pagefile.put() | Out-Null

    $PageFile = Get-CimInstance -ClassName Win32_PageFileSetting -Filter "Name like '%pagefile.sys'"
    $PageFile | Remove-CimInstance
    $PageFile = New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name= "${SWAPLOCATION}:\pagefile.sys" }
    $PageFile | Set-CimInstance -Property @{ InitialSize = $SWAPSIZE; MaximumSize = $SWAPSIZE }

    }
}

function disablesecurities {
    seplines
    
    Write-Host "Do you want to Disable Firewalls, Windows Defender, IE ESC [y/" -NoNewline
    write-color green N NL
    write-host "] : " -NoNewline
    $ANSWER=Read-Host

    if ( ${ANSWER} -eq "y" ) {
        write-host "Disabling Private network's firewall"
        Get-NetFirewallProfile -Name Private | Set-NetFirewallProfile -Enabled 0
        write-host "Disabling RealTime monitoring"
        Set-MpPreference -DisableRealtimeMonitoring 1
        write-host "Disabling IE ESC"
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Disk" -Name "TimeOutValue" -Value 100 -Type DWord
        write-host "Disabling ServerManagement page auto display"
        schtasks /Change /TN "Microsoft\Windows\Server Manager\ServerManager"  /Disable | out-null
        write-host "Enabling WINRM"
        Enable-PSRemoting -Confirm:$false
        Set-Item WSMan:\localhost\Client\TrustedHosts * -Force
        Restart-Service winrm
    }
}

function setNTP {
    seplines
    write-host "Do you want to set NTP servers to ${NTPSERVERS} [y/" -NoNewline
    write-color green N NL
    write-host "] : " -NoNewline
    $ANSWER=Read-Host
    if ( $ANSWER -eq "y" ) {
        w32tm /config /syncfromflags:manual /manualpeerlist:"${NTPSERVERS}"
    }
}

function setTZ {
    seplines
    write-host "Do you want to set the TimeZone to " -NoNewline
    write-color green "$TIMEZONE" NL
    Write-Host " (current timezone is " -NoNewline
    write-color green "$(tzutil.exe /g)" NL
    Write-Host ") [y/" -NoNewline
    write-color green N NL
    write-host "] : " -NoNewline
    $ANSWER=Read-Host
    if ( $ANSWER -eq "y" ) {
        tzutil /s "${TIMEZONE}"
    }
}

function checkHyperV {
seplines

#Check for Hyper-V feature"
    $HYPERVFEATURES=Get-WindowsFeature -Name "*hyper-v*"

    if ( ($HYPERVFEATURES|select Installed) -match "false" ) { 
        $HYPERVFEATURES
        Write-Host "Hyper-v features are not (all) installed, do you want to installed them [y/" -NoNewline
        write-color green N NL
        write-host "] : " -NoNewline
        $ANSWER=read-host  
        if ( ${ANSWER} -eq "y" ) {
                $RESULT=$HYPERVFEATURES|Install-WindowsFeature -Confirm:$false 
            }
        }

    if ($RESULT.RestartNeeded -eq "Yes") {
        write-host "Do you want to reboot the node now [y/" -NoNewline
        write-color green N NL
        write-host "] : " -NoNewline
        $ANSWER=Read-Host 
        if ( $ANSWER -eq "y" ) {
                write-color green "Restart in progress"
                Restart-Computer -Force -Confirm:$false
            }
        else
            {
            write-host "Reboot is needed to continue, script will end now :("
            exit 1
        }

    }
}



function checkip ($IPADD) {

$global:ERR=0
try {([ipaddress]$IPADD).IPAddressToString -eq $IPADD}
catch {return $false}
}


function Sub2Net ($subnet) {

$netMaskIP=[IPAddress]$subnet
$binaryString=[String]::Empty

$netMaskIP.GetAddressBytes() | % { $binaryString+=[Convert]::ToString($_, 2) }

return $binaryString.TrimEnd('0').Length

}


function createNetwork {

$ROLES=@("iSCSI1","iSCSI2","HYPERV","PRODUCTION","QUIT")


clear

write-host "Which role do you want to setup ( " -NoNewline
write-color green " $ROLES " NL
write-host ") : " -NoNewline
$ROLE=read-host 

if ( $ROLE -eq "QUIT" ) { $LOOP=1; break }

if ( $ROLE -like "iSCSI*") {

        $NETADP=Get-NetAdapter |?{$_.InterfaceDescription -notlike "Hyper-V*"} 
        $NETADP|select Name,VLANID,MacAddress,Status,LinkSpeed,InterfaceDescription | ft

        write-host "Select Interface dedicated to " -NoNewline
        write-color green "$ROLE"
        write-host "* 1 single interface for iSCSI roles "
        
        write-host "Enter Adapter name " -NoNewline
        write-color green "$(($NETADP|?{$_Name -like "*$ROLE*"}))" NL
        while ( $ISCSIADPTER -notin $($NETADP.name) ) {$ISCSIADPTER=Read-Host -p "?" }

        Write-Host "Do you want to rename this Adapter " -NoNewline
        write-color green ${ISCSIADPTER} NL
        Write-Host " [y/" -NoNewline
        write-color green N NL
        write-host "] : " -NoNewline
        $ANSWER=Read-host 

        if ( ${ANSWER} -eq "y" ) {
            write-host "Enter new name [" -NoNewline
            write-color green "${SHORTNAME}_NIC_${ROLE}" NL
            write-host "] : " -NoNewline
            $ANSWER=Read-host
            if ( ! $ANSWER ) { $ANSWER="${SHORTNAME}_NIC_${ROLE}"}
            Rename-NetAdapter -Name $ISCSIADPTER -NewName $ANSWER
            $ISCSIADPTER=$ANSWER 
        }




    switch ( $ROLE )
    {
        iSCSI1 { $VNICS=@("VNIC_INIT1","VNIC_FE1","VNIC_MR1") }
        iSCSI2 { $VNICS=@("VNIC_INIT2","VNIC_FE2","VNIC_MR2") }
    }

    if ( !(Get-VMSwitch -name "${SHORTNAME}_SW_${ROLE}" -ErrorAction SilentlyContinue) ) { 
        New-VMSwitch -name "${SHORTNAME}_SW_${ROLE}" -NetAdapterName "${ISCSIADPTER}" -AllowManagementOS 0 
        write-host "* VMswitch ""${SHORTNAME}_SW_${ROLE}"" created"
    }
    else {
        write-host "! VMswitch ""${SHORTNAME}_SW_${ROLE}"" already exist"
    }


    $VNICS|%{

    $VNIC=$_
    if ( ! ( (Get-VMNetworkAdapter -ManagementOS -Name "vEthernet (${SHORTNAME}_${VNIC})" -ErrorAction SilentlyContinue ) -or (Get-VMNetworkAdapter -ManagementOS -Name "${SHORTNAME}_${VNIC}" -ErrorAction SilentlyContinue) ) ) { 
        Add-VMNetworkAdapter -ManagementOS -Name "${SHORTNAME}_${VNIC}" -SwitchName "${SHORTNAME}_SW_${ROLE}"
        Rename-NetAdapter -name "vEthernet (${SHORTNAME}_${VNIC})" -newname "${SHORTNAME}_${VNIC}"
        write-host "* Virtual interface ""${SHORTNAME}_${VNIC}"" created"
        }
    else {
        write-host "! Virtual interface ""${SHORTNAME}_${VNIC}"" already exist"
        }

    $RESULT = (Get-NetIPAddress -InterfaceAlias "${SHORTNAME}_${VNIC}" -AddressFamily IPv4 -ErrorAction SilentlyContinue)
    $RESULT | Select-Object InterfaceAlias,IPAddress,PrefixLength | ft
    $ANSWER=read-host -p "Do you want to change this IP address [y/N]"
    if ( $ANSWER -eq "y" ) {
        $ERR="false"
        while ( $ERR -ne "true" ) {
            $IPADD=Read-Host -p "Enter new IP address"
            $ERR=checkip $IPADD
            }

        $ERR="false"
        $SUBNET=0
        while ( $ERR -ne "true" ) {
            $NETMASK=Read-Host -p "Enter Netmask or Subnet"
            if ( $NETMASK -in (1..32 )) {$ERR="true"}
            elseif ( $ERR=checkip $NETMASK ) { $SUBNET=1 }
              }
        $ERR="false"
        while ( $ERR -ne "true" ) {
            $VLAN=Read-Host -p "Enter VLANID [Empty if no VLAN]"
            if ( $VLAN -in (0..4094 )) {$ERR="true"}
            elseif ( ! ( $VLAN ) ) { $VLAN=0; $ERR = "true" }
            }

        if ( $RESULT.PrefixOrigin -eq "manual" ) { Remove-NetIPAddress -InterfaceIndex $RESULT.ifIndex -AddressFamily IPv4 -Confirm:$false | Out-Null }
        if ( $SUBNET -eq 1 ) { $NETMASK=Sub2Net $NETMASK}
        new-NetIPAddress -InterfaceAlias "${SHORTNAME}_${VNIC}" -AddressFamily IPv4 -IPAddress $IPADD -PrefixLength $NETMASK | Out-Null
        Set-VMNetworkAdapterVlan -VMNetworkAdapterName "${SHORTNAME}_${VNIC}" -VlanID ${VLAN} -ManagementOS -Access
    }
}



}

if ( $ROLE -in @("PRODUCTION","HyperV") ) {
    
    
    Get-NetAdapter |?{$_.InterfaceDescription -notlike "Hyper-V*"} |select Name,VLANID,MacAddress,Status,LinkSpeed,InterfaceDescription | ft
    Get-VMSwitch | select Name, SwitchType,AllowManagementOS | ft
    write-host ""
    write-host ""
    write-host "Select Interface or vSwitch dedicated to $ROLE"
    write-host " "
    write-host "* multiple interfaces can be used for HyperV, Production roles  (comma separation)"
    write-host "- HyperV role will be used for CSV, Heartbeat, LiveMigration"
    write-host "- Production role will be used for VMs network"
    write-host ""
    $ADAPTERS=Read-Host -p "Enter Adapter/vSwitch name (for multiple adapter use comma separation)"
    $ADAPTERS2=@()
    $i=0
    if ( ! ( $ADAPTERS -in (Get-VMSwitch).name ) ) {
    $ADAPTERS -split(",")|% {
        $i++
        $ADAPTER=$_
        if ( (($ADAPTERS -split(",")).count -gt 1) -and ($ADAPTER -in (Get-VMSwitch).name) ) { 
            Write-Host " ! sorry, Not possible to use multiple vswitch " 
            Read-Host
            createNetwork 
            }

        $ANSWER=Read-host "Do you want to rename this Adapter ${ADAPTER} [y/N]"

        if ( ${ANSWER} -eq "y" ) {
            $ANSWER=Read-host -p "Enter new name [${SHORTNAME}_NIC_${ROLE}${i}]"
            if ( ! $ANSWER ) { $ANSWER="${SHORTNAME}_NIC_${ROLE}${i}"}
            if ( $ANSWER -in $ADAPTERS ) { write-host "$ANSWER already exist, adapter will not be renamed";pause}
            else { Rename-NetAdapter -Name $ADAPTER -NewName $ANSWER }
            $ADAPTERS2+=$ANSWER
        }
        else {$ADAPTERS2+=$ADAPTER}
        

    }
    $SWITCHNAME="${SHORTNAME}_SW_${ROLE}"
    if ( Get-VMSwitch "$SWITCHNAME" -ErrorAction SilentlyContinue ) {
       
        write-host "Switch $SWITCHNAME already exist"
        write-host "- check for teaming design if needed, no change will be applyed"
        pause
    
    }
    else {
        New-VMSwitch -Name "$SWITCHNAME" -NetAdapterName $ADAPTERS2 -EnableEmbeddedTeaming $true -AllowManagementOS $false -MinimumBandwidthMode Weight
        
        }
    }
    else { $SWITCHNAME=$ADAPTERS }

   $VNIC="VNIC_${ROLE}"
    if ( ! ( (Get-VMNetworkAdapter -ManagementOS -Name "vEthernet (${SHORTNAME}_${VNIC})" -ErrorAction SilentlyContinue ) -or (Get-VMNetworkAdapter -ManagementOS -Name "${SHORTNAME}_${VNIC}" -ErrorAction SilentlyContinue) ) ) { 
        Add-VMNetworkAdapter -ManagementOS -Name "${SHORTNAME}_${VNIC}" -SwitchName "$SWITCHNAME"
        Rename-NetAdapter -name "vEthernet (${SHORTNAME}_${VNIC})" -newname "${SHORTNAME}_${VNIC}"
        write-host "* Virtual interface ""${SHORTNAME}_${VNIC}"" created"
        }
    else {
        write-host "! Virtual interface ""${SHORTNAME}_${VNIC}"" already exist"
        }

    $RESULT = (Get-NetIPAddress -InterfaceAlias "${SHORTNAME}_${VNIC}" -AddressFamily IPv4 -ErrorAction SilentlyContinue)
    $RESULT | Select-Object InterfaceAlias,IPAddress,PrefixLength | ft
    $ANSWER=read-host -p "Do you want to change this IP address [y/N]"
 
    if ( $ANSWER -eq "y" ) {
 
        $ERR="false"
        while ( $ERR -ne "true" ) {
            $IPADD=Read-Host -p "Enter new IP address"
            $ERR=checkip $IPADD
            }

        $ERR="false"
        $SUBNET=0
        while ( $ERR -ne "true" ) {
            $NETMASK=Read-Host -p "Enter Netmask or Subnet"
            if ( $NETMASK -in (1..32 )) {$ERR="true"}
            elseif ( $ERR=checkip $NETMASK ) { $SUBNET=1 }
            }
            
        if ( $RESULT.PrefixOrigin -eq "manual" ) { Remove-NetIPAddress -InterfaceIndex $RESULT.ifIndex -AddressFamily IPv4 -Confirm:$false | Out-Null }
        if ( $SUBNET -eq 1 ) { $NETMASK=Sub2Net $NETMASK}

        $ERR="false"
        Remove-Variable -Name GATEWAY -ErrorAction SilentlyContinue
        while ( $ERR -ne "true" ) {
            $GATEWAY=Read-host -p "Enter Gateway [empty if no Gateway]"
            if ($GATEWAY) { $ERR=checkip $GATEWAY }
            else { $ERR = "true" }
        }

        $ERR="false"
        while ( $ERR -ne "true" ) {
            $VLAN=Read-Host -p "Enter VLANID [Empty if no VLAN]"
            if ( $VLAN -in (0..4094 )) {$ERR="true"}
            elseif ( ! ( $VLAN ) ) { $VLAN=0; $ERR = "true" }
        }        
        
        if (! ( $GATEWAY ) ){
            new-NetIPAddress -InterfaceAlias "${SHORTNAME}_${VNIC}" -AddressFamily IPv4 -IPAddress $IPADD -PrefixLength $NETMASK | Out-Null
            }
        else {
            new-NetIPAddress -InterfaceAlias "${SHORTNAME}_${VNIC}" -AddressFamily IPv4 -IPAddress $IPADD -PrefixLength $NETMASK -DefaultGateway $GATEWAY | Out-Null
            }
        Set-VMNetworkAdapterVlan -VMNetworkAdapterName "${SHORTNAME}_${VNIC}" -VlanID ${VLAN} -ManagementOS -Access
    }





# NEW VNIC
    $ANSWER = read-host -p "Do you want to create a new virtual interface for this switch [y/N]"
    if ( $ANSWER -eq "y" ) {
    write-host "Existing virtual interface associated to this switch"
    Get-VMNetworkAdapter -ManagementOS -SwitchName $SWITCHNAME | select Name| ft

    $NEWVNIC=read-host -p "Please enter a name for this interface : ${SHORTNAME}_${VNIC}_xxxx  "
    
    if ( ! ( (Get-VMNetworkAdapter -ManagementOS -Name $NEWVNIC -ErrorAction SilentlyContinue ) ) ) { 
        Add-VMNetworkAdapter -ManagementOS -Name "${NEWVNIC}" -SwitchName "$SWITCHNAME"
        Rename-NetAdapter -name "vEthernet (${NEWVNIC})" -newname "${NEWVNIC}"
        write-host "* Virtual interface ""${NEWVNIC}"" created"
        }
    else {
        write-host "! Virtual interface ""${NEWVNIC}"" already exist"
        }


    $RESULT = (Get-NetIPAddress -InterfaceAlias "${NEWVNIC}" -AddressFamily IPv4 -ErrorAction SilentlyContinue)
    $RESULT | Select-Object InterfaceAlias,IPAddress,PrefixLength | ft
    $ANSWER=read-host -p "Do you want to change this IP address [y/N]"
    if ( $ANSWER -eq "y" ) {
        $ERR="false"
        while ( $ERR -ne "true" ) {
            $IPADD=Read-Host -p "Enter new IP address"
            $ERR=checkip $IPADD
            }

        $ERR="false"
        $SUBNET=0
        while ( $ERR -ne "true" ) {
            $NETMASK=Read-Host -p "Enter Netmask or Subnet"
            if ( $NETMASK -in (1..32 )) {$ERR="true"}
            elseif ( $ERR=checkip $NETMASK ) { $SUBNET=1 }
            }
            
        if ( $RESULT.PrefixOrigin -eq "manual" ) { Remove-NetIPAddress -InterfaceIndex $RESULT.ifIndex -AddressFamily IPv4 -Confirm:$false | Out-Null }
        if ( $SUBNET -eq 1 ) { $NETMASK=Sub2Net $NETMASK}

        $ERR="false"
        while ( $ERR -ne "true" ) {
            Remove-Variable -Name GATEWAY -ErrorAction SilentlyContinue
            $GATEWAY=Read-host -p "Enter Gateway [empty if no Gateway]"
            if ($GATEWAY) { $ERR=checkip $GATEWAY }
            else { $ERR = "true" }
        }
  
        $ERR="false"      
        while ( $ERR -ne "true" ) {
            $VLAN=Read-Host -p "Enter VLANID [Empty if no VLAN]"
            if ( $VLAN -in (0..4094 )) {$ERR="true"}
            elseif ( ! ( $VLAN ) ) { $VLAN=0; $ERR = "true" }
        }    
        if (! ( $GATEWAY ) ){
            new-NetIPAddress -InterfaceAlias "${NEWVNIC}" -AddressFamily IPv4 -IPAddress $IPADD -PrefixLength $NETMASK | Out-Null
            }
        else {
            new-NetIPAddress -InterfaceAlias "${NEWVNIC}" -AddressFamily IPv4 -IPAddress $IPADD -PrefixLength $NETMASK -DefaultGateway $GATEWAY | Out-Null
            }
        Set-VMNetworkAdapterVlan -VMNetworkAdapterName "${NEWVNIC}" -VlanID ${VLAN} -ManagementOS -Access
    }
}


}
}



#
# Main Script
#
#
#####################################


disablesecurities
setpagefile
setNTP
setTZ
checkHyperV
setshortname


$global:LOOP=0

while ( $LOOP -eq 0 ) { createNetwork }

