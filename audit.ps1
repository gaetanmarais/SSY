﻿#########################################################################
#
#  Check VMware and SANsymphony Best practices from VMware Powercli
#
#
#  Author  : Gaetan MARAIS [DataCore]
#  Date    : 2025/04/22
#
#  Version : 1.0   -  ESX version of datacollection
#  Version : 2.0   -  Adding SSY collection and reporting
#
#########################################################################

param(
     [Parameter(Mandatory)]
     [string]$VCENTER,

     [Parameter(Mandatory)]
     [string]$UserName,

     [Parameter(Mandatory)]
     [string]$Password,

     [Parameter(Mandatory)]
     [string]$Cluster,

     [Parameter(Mandatory)]
     [string]$SANsymphony,

     [Parameter(Mandatory)]
     [string]$SSYuser,

     [Parameter(Mandatory)]
     [string]$SSYpwd

 )

 #.\Audit.ps1 -VCENTER 10.12.104.100 -UserName administrator@vsphere.local -Password Datacore1! -Cluster Cluster104 -SANsymphony SDS -SSYuser dcsadmin -SSYpwd Datacore1

 $HRVERSION="1.2"
 $COLLECTIONDATE=Get-Date



 #Get local folder
 if ($psise) { $SCRIPTPATH=Split-Path $psise.CurrentFile.FullPath }
 else { $SCRIPTPATH=$PSScriptRoot   }

 $TMPPATH="$SCRIPTPATH\tmp"

 if ( ! (Test-Path $TMPPATH ) ) { New-Item -Path $TMPPATH -ItemType Directory | Out-Null}


 function wait ($TIMEOUT) {

if ( ! ($TIMEOUT) -or ($TIMEOUT -gt 9) ) {$TIMEOUT=9}

$T=$TIMEOUT
while ($T -ne 0)
    {
    write-host -NoNewline "`b$T" -ForegroundColor Yellow
    sleep 1
    $T--
    }
    write-host -NoNewline "`b  " -ForegroundColor Yellow
}




        #Install-PackageProvider -Name NuGet

        if ( !(Get-PackageProvider -name Nuget -ListAvailable -ErrorAction SilentlyContinue)  ) {
            write-host "Nuget Package provider is not yet installed, this is mandatory" -ForegroundColor Red
            write-host "      If you don't want to install it on your system, it's time to break the script :)" -ForegroundColor yellow
            wait 10
            write-host " "


            try { Install-PackageProvider -name "Nuget" -MinimumVersion "2.8.5.201" -Force -Confirm:$false -ErrorAction Stop}
            catch { 
                write-host 'Unable to install Packe Provider "Nuget"' -ForegroundColor Red
                write-host 'Installation will stop, please try to install it manualy as Administrator' -ForegroundColor Red
                wait 10
                exit 1
            }



        }

        write-host " "
        # Import PSWriteHTML module to generate cool HTML files     -RequiredVersion 0.0.182
    try { Import-Module -Name PSWriteHtml -ErrorAction Stop }
    catch {
        Write-host "PSWriteHTML Powershell module is not installed, this script will try to install it, if it failed please run the script with administrator privileges." -ForegroundColor Red
        Write-host "      If you don't want to install it on your system, it's time to break the script :)" -ForegroundColor yellow
        wait 10
        $importPSWRITEHTML="ERROR"
        }
    
    if ( $importPSWRITEHTML -eq "ERROR" ) {

        try { Install-Module -name pswritehtml -AllowClobber -Confirm:$false -Force -ErrorAction Stop            }
        catch {
            Write-host "
            PSWriteHTML Powershell module could not be installed automatically please run this command manualy as Administrator." -ForegroundColor Red
            Write-host "    install-module -name pswritehtml -AllowClobber -Confirm:$false -Force  " -ForegroundColor yellow
            wait 10
           # Exit 1           
            }

        }


        write-host " "
        # Import 
    Try {
        $pcliversion = (get-Module -ListAvailable -name VMware.VimAutomation.Core)
        if ( ! ($pcliversion) ) {

            Write-Host "
            VMware PowerCLI not found, we will try to install it for you :)" -ForegroundColor Red
            Write-host "      If you don't want to install it on your system, it's time to break the script :)" -ForegroundColor yellow
            wait 10
            try { Install-Module -name VMware.VimAutomation.Core -AllowClobber -Confirm:$false -force -ErrorAction Stop 
                write-host "Module installed, script will stop here, you will re-run it"

                $POWERCLICFG=Get-PowerCLIConfiguration -Scope AllUsers
                if ( $POWERCLICFG.InvalidCertificateAction -ne "Ignore" ) { Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope User -Confirm:$false | out-null}
                if ( $POWERCLICFG.DefaultVIServerMode -ne "Multiple" ) { Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope User -Confirm:$false | out-null}
                if ( $POWERCLICFG.DisplayDeprecationWarnings -ne "False" ) { Set-PowerCLIConfiguration -DisplayDeprecationWarnings 0 -Scope User -Confirm:$false | out-null}
                if ( $POWERCLICFG.ParticipateInCEIP -ne "True" ) { Set-PowerCLIConfiguration -ParticipateInCEIP $true -Scope User -Confirm:$false | out-null}

                wait 10
                #exit 1
                }
            catch { 
                write-host "Unable to install PowerCLI, please try to install it by yourself" -ForegroundColor Red
                write-host "    Install-Module -name VMware.PowerCLI -AllowClobber -Confirm:`$false"    -ForegroundColor yellow
                wait 10
                exit 2
             }
        }


        elseif ( $pcliversion.Version.major -lt 13)
            {
                Write-Host "
                PowerCLI version is too old ${pcliversion}.Version (Minimum required: v 13.x)" -ForegroundColor red
                Write-Host "    We will try to update it for you :)" -ForegroundColor red
                 try { Update-Module -name VMware.PowerCLI -AllowClobber -Confirm:$false -Force -ErrorAction Stop }
            catch { 
                write-host "Unable to Update PowerCLI, please try to install it by yourself running as Administrator level"
                write-host "    Update-Module -name VMware.PowerCLI -AllowClobber -Confirm:`$false" -ForegroundColor Yellow
                wait 10
                exit 2
             }
            
           }
        }
    Catch  { 
        Write-Host "PowerCLI 13 is not installed"
        Write-Host "  open powershell admin session"
        Write-Host "  PS# Install-Module -name VMware.PowerCLI"
        wait 10
        exit
        }


        $POWERCLICFG=Get-PowerCLIConfiguration -Scope AllUsers
        if ( $POWERCLICFG.InvalidCertificateAction -ne "Ignore" ) { Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope User -Confirm:$false | out-null}
        if ( $POWERCLICFG.DefaultVIServerMode -ne "Multiple" ) { Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope User -Confirm:$false | out-null}
        if ( $POWERCLICFG.DisplayDeprecationWarnings -ne "False" ) { Set-PowerCLIConfiguration -DisplayDeprecationWarnings 0 -Scope User -Confirm:$false | out-null}
        if ( $POWERCLICFG.ParticipateInCEIP -eq "True" ) { Set-PowerCLIConfiguration -ParticipateInCEIP $false -Scope User -Confirm:$false | out-null}


 try { Connect-VIServer -Server $VCENTER -User $UserName -Password $Password -ErrorAction Stop}
 catch { write-host $_
        exit 1}


 


 
 $SSYHOSTDETAILS=@()

 try { $VICLUSTER=Get-Cluster -Name $CLUSTER -ErrorAction Stop}
 catch { write-host "Cluster '$CLUSTER' does not exist or is not managed by '$VCENTER'" 
 exit 1
 }
 
 #Cluster configuration collection
 $HACONFIG=$VICLUSTER.ExtensionData.Configuration.DasConfig
 Write-Host "`n##############################################################"
 Write-host "Cluster configuration"
 $VICLUSTER|ft -AutoSize
 $DATASTORES=Get-Datastore
 $HACONFIG|select VmMonitoring,HostMonitoring,VmComponentProtecting,@{N="HeartbeatDatastore";E={$VAR=$_.HeartbeatDatastore;($DATASTORES|?{$_.id -in $VAR}).name}},HBDatastoreCandidatePolicy,option|ft -AutoSize



 #VMware host detail collection
 $VMHOSTS=$VICLUSTER|get-VMhost | Sort-Object
  
 

 Write-Host "`n##############################################################"

 $i=0
 $SSYDETAILS_=@()
 $VMHDETAILS_=@()
 $DEVICES_=@()
 $ISCSITARGETS_=@()

 $VMHOSTS | % {
 $VMHOST=$_
 
 $CPUHZ=$VMHOST.ExtensionData.Hardware.CpuInfo.Hz

 $ISCSIHBA=$VMHOST|Get-VMHostHba -Type IScsi

 $esxcli = Get-EsxCli -VMHost $VMHOST -V2

 $ISCSITARGETS=$ISCSIHBA|Get-IScsiHbaTarget | select @{N="VMHost";E={$VAR=$_.VMhostId;$VMHOSTS|?{$_.id -eq $VAR}}},type,Name,iSCSIname| Sort-Object -Property VMhost,Type,name
 $ISCSITARGETS_+=$ISCSITARGETS

 $DATASTORES=$VMHOST|Get-Datastore|select Name,@{N="DEVICE";E={$_.ExtensionData.info.vmfs.Extent.diskname}}|Sort-Object
 

 $DEVICES=$VMHOST|Get-ScsiLun | ? {$_.Vendor -eq "DataCore"}|select VMhost,@{N="DataStore/(Name)";E={$VAR=$_.CanonicalName;if ( ($NAME=$DATASTORES|?{$_.DEVICE -eq $VAR}|select Name).name) {$NAME.name} else {"($($_.ExtensionData.displayname))" } }},CanonicalName,CommandsToSwitchPath,BlocksToSwitchPath,CapacityGB,MultipathPolicy,@{N="Paths";E={($_|Get-ScsiLunPath).count}}|Sort-Object -Property "DataStore/(Name)"
 $DEVICES_+=$DEVICES

 $VMHOSTSERVICES=$VMHOST|Get-VmHostService


 $VMHDETAILS = new-object -TypeName PSObject
 $VMHDETAILS | Add-Member -MemberType NoteProperty -Name "VMHOST" -value $VMHOST.Name
 $VMHDETAILS | Add-Member -MemberType NoteProperty -Name "iSCSI alias" -value $ISCSIHBA.IScsiAlias
 $VMHDETAILS | Add-Member -MemberType NoteProperty -Name "iSCSI DelayAck" -value ($ISCSIHBA.ExtensionData.AdvancedOptions|?{$_.key -eq "DelayedAck"}).value
 $VMHDETAILS | Add-Member -MemberType NoteProperty -Name "iSCSI P.Binding" -Value ($esxcli.iscsi.networkportal.list.Invoke().vmknic -join ",")
 $VMHDETAILS | Add-Member -MemberType NoteProperty -Name "DiskMaxIOSize" -value (Get-AdvancedSetting -Entity $VMHOST.Name -Name Disk.DiskMaxIOSize).Value
 $VMHDETAILS | Add-Member -MemberType NoteProperty -Name "NTPD" -Value ($VMHOSTSERVICES|?{$_.key -eq "ntpd"}).policy
 $VMHDETAILS | Add-Member -MemberType NoteProperty -Name "NTP Target" -Value ((get-VMHostNtpServer -VMHost $VMHOST) -join " ")
 $VMHDETAILS | Add-Member -MemberType NoteProperty -Name "SSHD" -Value ($VMHOSTSERVICES|?{$_.key -eq  "TSM-SSH"}).policy

 $VMHDETAILS_+=$VMHDETAILS
Write-Host "VMhost $VMHOST details"
 $VMHDETAILS 

Write-Host "`niSCSI connections"
 $ISCSITARGETS | ft -AutoSize

Write-Host "`nDataCore Storage details"
 $DEVICES | ft -AutoSize

Write-Host "`n##############################################################"
 


#Create DumpOSInfo.ps1 .... script that will be executed locally on SSY servers to gather OS details
$DUMPOSINFO = @'


clear

$COLLECTIONDATE=$(get-date -Format "yyyMMdd-HHmmss")
$OUTPATH="$env:tmp\${env:COMPUTERNAME}_"
$OUTFILE="${OUTPATH}$COLLECTIONDATE.xml"



# Get the installation path of SANsymphonyV
$bpKey = 'BaseProductKey'
$regKey = Get-Item "HKLM:\Software\DataCore\Executive"
$strProductKey = $regKey.getValue($bpKey)
$regKey = Get-Item "HKLM:\$strProductKey"
$installPath = $regKey.getValue('InstallPath')

Import-Module "$installPath\DataCore.Executive.Cmdlets.dll" -DisableNameChecking -ErrorAction Stop

connect-dcsserver | out-null

$dcsobj=Export-DcsObjectModel -OutputDirectory "$env:tmp"
if ( Test-Path "${OUTPATH}DcsObjectModel.xml" ) { Remove-Item "${OUTPATH}DcsObjectModel.xml" -Force } 
Rename-Item -Path "${env:tmp}\DcsObjectModel.xml" -NewName "${OUTPATH}DcsObjectModel.xml" -force
if ( Test-Path "${OUTPATH}DcsLivePerformance.xml" ) { Remove-Item "${OUTPATH}DcsLivePerformance.xml" -Force } 
Rename-Item -Path "${env:tmp}\DcsLivePerformance.xml" -NewName "${OUTPATH}DcsLivePerformance.xml" -force


function AddElement2Xml($para,$name,$arg){
    
    $xmlWriter.WriteStartElement($para -replace(" ","__") -replace("/","SSLASHH") -replace("\(","PARAOPEN") -replace("\)","PARACLOSE") -replace("\&","ETCOMMERCIAL") -replace("\#","DIESE") -replace("\+","PPLUSS")) 
    For ($i=0; $i -lt ($arg|Measure-Object).Count; $i++) {
        if ( $arg[$i].$name) {
            if ( (($arg[$i].$name)[0]) -match "^[\d\.]+$" ) {$xmlWriter.WriteStartElement("_"+$arg[$i].$name)}
            #else {$xmlWriter.WriteStartElement($arg[$i].$name  -replace(" ","__") -replace("/","SSLASHH") -replace("\(","PARAOPEN") -replace("\)","PARACLOSE") -replace("\&","ETCOMMERCIAL") -replace("\#","DIESE") -replace("\+","PPLUSS")) }
			else {$xmlWriter.WriteStartElement($arg[$i].$name  -replace(" ","_") -replace("/","_") -replace("\(","_") -replace("\)","_") -replace("\&","_") -replace("\#","_") -replace("\+","PLUS")) }
            }
        $arg[$i]|gm -MemberType *Property | % { 
            $prop=$_.name
            $value=$arg[$i].$prop
           # $prop=$prop -replace(" ","__") -replace("/","SSLASHH") -replace("\(","PARAOPEN") -replace("\)","PARACLOSE") -replace("\&","ETCOMMERCIAL") -replace("\#","DIESE") -replace("\+","PPLUSS")
			$prop=$prop -replace(" ","_") -replace("/","_") -replace("\(","_") -replace("\)","_") -replace("\&","_") -replace("\#","_") -replace("\+","_")
            $xmlWriter.WriteElementString($prop,$value)
            }
        if ( $arg[$i].$name ) {$xmlWriter.WriteEndElement()}
        }
    $xmlWriter.WriteEndElement()
}


$xmlWriter = New-Object System.XMl.XmlTextWriter($OUTFILE, $Null)

$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = 1
$XmlWriter.IndentChar = "`t"

$xmlWriter.WriteStartDocument()
    $xmlWriter.WriteStartElement("Windows")

        $VAL=(Get-PhysicalDisk |? {$_.FriendlyName -notlike "Datacore*"}|select-object DeviceId,FriendlyName,SerialNumber,MediaType,Size)
        AddElement2Xml PhysicalDisk SerialNumber $VAL
        
        
        $VAL=Get-Volume  | ? {$_.DriveType -eq "Fixed" -and $_.DriveLetter }|Select-Object UniqueId,DriveLetter,FriendlyName,FileSystemType,HealthStatus,OperationalStatus,Size,SizeRemaining,DedupMode,AllocationUnitSize
        AddElement2Xml Volumes DriveLetter $VAL
        
        
        $VAL=(Get-CimInstance Win32_PageFileSetting |Select-Object Name,InitialSize,MaximumSize)
        AddElement2Xml Pagefile OS $VAL
        

        $MEMDUMP=@("None","Complete memory dump","Kernel memory dump","Small memory dump")

        $VAL=(Get-WmiObject Win32_OSRecoveryConfiguration -EnableAllPrivileges|Select-Object AutoReboot,DebugFilePath,@{N="DebugInfoType";E={$MEMDUMP[$_.DebugInfoType]}},OverwriteExistingDebugFile,SendAdminAlert,WriteDebugInfo,WriteToSystemLog)
        AddElement2Xml MemoryDump OS $VAL


        $VAL = New-Object -TypeName PSObject
        w32tm /query /status|%{
        $TEMP=$_
        if ( $TEMP -like "Last*" -or $TEMP -like "Source:*" ) {
                $PROP=($TEMP -split(": "))[0]
                $VALUE=($TEMP -split(": "))[1]
                $VAL|Add-Member -MemberType NoteProperty -Name $PROP -Value $VALUE
            }
        }
        AddElement2Xml NTP NTP $VAL



        $VAL = @()
        get-content C:\windows\system32\drivers\etc\hosts | % { $_ | Select-String -Pattern "^\s*$" -NotMatch | Select-String -Pattern "^#" -NotMatch }|%{
        $TEMP=$_
                $item= New-Object PSObject
                $PROP=($TEMP -split("\s+") )[0]
                $VALUE=($TEMP -split("\s+") )[1]
                $item | add-member -Type NoteProperty -Name Hostname -Value $VALUE
                $item | add-member -Type NoteProperty -Name IP -Value $PROP

                $VAL+=$item
        }
        AddElement2Xml EtcHosts Hostname $VAL



        $xmlWriter.WriteStartElement("Netadapter")
        Get-NetAdapter|%{
            $NETWORK=$_|Select-Object *,@{N="IP";E={$IP=(Get-NetIPAddress -InterfaceIndex $_.ifIndex); $IP.IPv4Address +"/"+ $IP.PrefixLength}}
            AddElement2Xml ($NETWORK.ifalias) nada $NETWORK
            }
        $xmlWriter.WriteEndElement()


        $xmlWriter.WriteStartElement("NetadapterBinding")
        Get-NetAdapter|%{
            $TEMP=$_|Select-Object *
            $NETWORK = New-Object -TypeName PSObject
            $NETWORK|Add-Member -MemberType NoteProperty -Name ifAlias -Value $TEMP.ifAlias
            ($TEMP|Get-NetAdapterBinding|Select-Object DisplayName,Enabled)|%{$NETWORK|Add-Member -MemberType NoteProperty -Name $_.DisplayName -Value $_.Enabled}
            AddElement2Xml $NETWORK.ifalias nada $NETWORK
            }
        $xmlWriter.WriteEndElement()


        $xmlWriter.WriteStartElement("NetAdapterAdvancedProperty")
        Get-NetAdapter|%{
            $TEMP=$_|Select-Object *
            $NETWORK = New-Object -TypeName PSObject
            $NETWORK|Add-Member -MemberType NoteProperty -Name ifAlias -Value $TEMP.ifAlias
            ($TEMP|Get-NetAdapterAdvancedProperty|Select-Object DisplayName,DisplayValue)|%{$NETWORK|Add-Member -MemberType NoteProperty -Name $_.DisplayName -Value $_.DisplayValue}
            AddElement2Xml $NETWORK.ifAlias nada $NETWORK
            }
        $xmlWriter.WriteEndElement()


        $xmlWriter.WriteStartElement("iSCSIConnection")
        $VAL=Get-IscsiConnection
        AddElement2Xml iSCSIconnections ConnectionIdentifier $VAL
        $xmlWriter.WriteEndElement()

        $xmlWriter.WriteStartElement("Software")
        #$VAL=(Get-WmiObject -Class Win32_Product|select-object Name,Vendor,Version,@{N="InstallDate";E={([datetime]::parseexact($_.InstallDate, "yyyyMMdd", [System.Globalization.CultureInfo]::InvariantCulture)).ToString("yyyy/MM/dd")}}|sort-object -Descending InstallDate)
	    $VAL=( get-itemproperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" |?{$_.DisplayName}|select-object DisplayName,Publisher,DisplayVersion,@{N="InstallDate";E={([datetime]::parseexact($_.InstallDate, "yyyyMMdd", [System.Globalization.CultureInfo]::InvariantCulture)).ToString("yyyy/MM/dd")}})
        $VAL+=( get-itemproperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"|?{$_.DisplayName} |select-object DisplayName,Publisher,DisplayVersion,@{N="InstallDate";E={([datetime]::parseexact($_.InstallDate, "yyyyMMdd", [System.Globalization.CultureInfo]::InvariantCulture)).ToString("yyyy/MM/dd")}})|sort-object -Descending InstallDate
	    AddElement2Xml InstalledSoftware DisplayName $VAL
        $xmlWriter.WriteEndElement()
        

        $xmlWriter.WriteStartElement("WindowsUpdate")
        $VAL=(Get-HotFix|sort-object -Descending InstalledOn|select HotFixID,Description,InstalledOn,Caption)
        AddElement2Xml WindowsUpdate HotFixID $VAL
        $xmlWriter.WriteEndElement()


        $xmlWriter.WriteStartElement("System")
        $VAL=(Get-CimInstance -ClassName Win32_OperatingSystem| select CSName,Caption,InstallDate,LastBootUpTime)
        AddElement2Xml Windowsdetails CSName $VAL
        $xmlWriter.WriteEndElement()

        $xmlWriter.WriteStartElement("EventLog")
        $VAL=(Get-EventLog -LogName System -Newest 10 -InstanceId 13,41,1074,6008,6009,1001,7045|select index,TimeGenerated,EntryType,Source,InstanceId,UserName,Message)
        AddElement2Xml Reboot_and_Crash index $VAL
        $VAL=(Get-EventLog -LogName System -Newest 100 -EntryType Error|select index,TimeGenerated,EntryType,Source,InstanceId,UserName,Message)
        AddElement2Xml Last100 index $VAL

        $xmlWriter.WriteEndElement()
                

$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()

write-host "${OUTPATH}DcsObjectModel.xml"
write-host "${OUTPATH}DcsLivePerformance.xml"
write-host "${OUTFILE}"



'@
    Set-Content -Path "$TMPPATH/DumpOSInfo.ps1" -Value $DUMPOSINFO


$SSY_=get-vm | ? {$_.name -like "*$SANsymphony*"} | Sort-Object
$VMHOST | get-vm | ? {$_.name -like "*$SANsymphony*"} | Sort-Object | % {
     $SSY=$_
     $SSYSCSI=$SSY|Get-ScsiController 
     $SSYHDD=$SSY|Get-HardDisk
     $SSYNET=$SSY|get-networkadapter
     $SSYPASSTHROUGH=($SSY|Get-PassthroughDevice -ErrorAction SilentlyContinue).Name -join ","

     $SSYDETAILS = new-object -TypeName PSObject
     $SSYDETAILS | Add-Member -MemberType NoteProperty -Name "Name" -Value $SSY.name 
     $SSYDETAILS | Add-Member -MemberType NoteProperty -Name "CPU" -Value ($SSY.NumCpu*$SSY.CoresPerSocket)
     $SSYDETAILS | Add-Member -MemberType NoteProperty -Name "CPU Res." -Value $SSY.ExtensionData.Config.CpuAllocation.Reservation
     $SSYDETAILS | Add-Member -MemberType NoteProperty -Name "CPU Needs" -Value $([math]::Round($CPUHZ/1000/1000)*($SSY.NumCpu*$SSY.CoresPerSocket))
     $SSYDETAILS | Add-Member -MemberType NoteProperty -Name "Memory" -Value $SSY.MemoryGB 
     $SSYDETAILS | Add-Member -MemberType NoteProperty -Name "Memory Res." -Value $SSY.ExtensionData.Config.MemoryReservationLockedToMax
     $SSYDETAILS | Add-Member -MemberType NoteProperty -Name "VM Latency" -Value ($SSYLATENCY=$SSY.ExtensionData.Config.LatencySensitivity.level)
     $SSYDETAILS | Add-member -MemberType NoteProperty -Name "VMxnet3" -value ($SSYNET|?{$_.type -eq "Vmxnet3"}).count
     $VAR=""
     $SSYSCSI|select type,@{N="HDD";E={$CTRLKEY=$_.ExtensionData.Key;($SSYHDD|?{$_.ExtensionData.ControllerKey -eq $CTRLKEY}).count}} | % {
        $VAR+=( "$($_.type)=$($_.HDD)  " )
        }
     $SSYDETAILS | Add-member -MemberType NoteProperty -Name "HDDs" -value $VAR
     $SSYDETAILS | Add-member -MemberType NoteProperty -Name "PASSTHROUGH" -value $SSYPASSTHROUGH
     
     $SSYDETAILS_+=$SSYDETAILS


     $SDSINSTALLPATH="c:\program files\datacore\sansymphony"

     Copy-VMGuestFile -LocalToGuest -Source $TMPPATH/DumpOSInfo.ps1  -Destination "$SDSINSTALLPATH" -VM $SSY.name -Force -GuestUser $SSYuser -GuestPassword $SSYpwd
     $output=invoke-vmscript -ScriptText ". ""$SDSINSTALLPATH\DumpOsInfo.ps1""" -VM $SSY.name -ScriptType Powershell -GuestUser $SSYuser -GuestPassword $SSYpwd
     $output.ScriptOutput -split "`r?`n" | % {
        $source=$_
        if ( $source -like "*:\*") { Copy-VMGuestFile -GuestToLocal -Source $source -Destination $TMPPATH -VM $SSY.name -Force -GuestUser $SSYuser -GuestPassword $SSYpwd }
     }
     



 }
 Write-Host "`nSSY nodes details"
 $SSYDETAILS | ft -AutoSize

 $i++
}

    #Read DCSobjectModel
    [xml]$DCSOBJECTMODEL=(Get-ChildItem -Path $TMPPATH -Filter "$(${SSY}.name)_DcsObjectModel.xml" |get-content)
    [xml]$DCSPERFORMANCEMODEL=(Get-ChildItem -Path $TMPPATH -Filter "$(${SSY}.name)_DcsLivePerformance.xml" |get-content)
    

    #Generation of a dictionnary about Performancemodel
    
    [string[]]$IDS = $DCSPERFORMANCEMODEL.LivePerformance.ObjectIds.ChildNodes | %{ $_.'#text'}
    [System.Xml.XmlElement[]]$PERFDATA = $DCSPERFORMANCEMODEL.LivePerformance.ChildNodes | Select-Object -Skip 1
    [System.Xml.XmlElement[]]$Objects = $DCSOBJECTMODEL.DataRepository.ChildNodes
    [System.Collections.Generic.Dictionary[string,object]]$PERFORMANCEDATA =  [System.Collections.Generic.Dictionary[string,object]]::new()
    $Namespace = New-Object -TypeName "System.Xml.XmlNamespaceManager" -ArgumentList $DCSOBJECTMODEL.NameTable
    $Namespace.AddNamespace("ns", $DCSOBJECTMODEL.DocumentElement.NamespaceURI)
    
    for ($i=0; $i -lt $IDS.Count; $i++){
        $PERFORMANCEDATA[$ids[$i]] = [PsCustomObject][Ordered]@{
            Perf = $PERFDATA[$i]
            Object = $DCSOBJECTMODEL.DataRepository.SelectSingleNode("//*[ns:Id='$($IDS[$i])']", $Namespace)
        }
    }
    # $id = "3833f156a8b14b28952a093e9b7f6f03"   ID of any object
    # $PERFDATA[$id].object     detail of the object
    # $PERFDATA[$id].perf       performance detail of the object


    
    $DCSSERVER=$DCSOBJECTMODEL.DataRepository.ServerHostData
    $DCSPOOL=$DCSOBJECTMODEL.DataRepository.DiskPoolData
    $DCSPOOLMEMBER=$DCSOBJECTMODEL.DataRepository.PoolMemberData
    $DCSSERVERPORT=$DCSOBJECTMODEL.DataRepository.ServeriScsiPortData
    $DCSCLIENT=$DCSOBJECTMODEL.DataRepository.ClientHostData
    $DCSVDISK=$DCSOBJECTMODEL.DataRepository.VirtualDiskData
    $DCSCLIENTSERVER=$DCSOBJECTMODEL.DataRepository.ClientServerRelationData
    $DCSISCSI=$DCSOBJECTMODEL.DataRepository.ServeriScsiPortData
    $DCSVIMHOST=$DCSOBJECTMODEL.DataRepository.VimHostData
    $DCSVIRTUALDISK=$DCSOBJECTMODEL.DataRepository.VirtualDiskData|?{$_.subtype -ne "Trunk"}
    $DCSLOGICALDISK=$DCSOBJECTMODEL.DataRepository.StreamLogicalDiskData
    $DCSLOGICALUNIT=$DCSOBJECTMODEL.DataRepository.VirtualLogicalUnitData
    $DCSPROFILE=$DCSOBJECTMODEL.DataRepository.StorageProfileData
    $DCSSNAPSHOT=$DCSOBJECTMODEL.DataRepository.SnapshotData
    $DCSROLLBACK=$DCSOBJECTMODEL.DataRepository.RollbackData
    $DCSDVAPOOL=$DCSOBJECTMODEL.DataRepository.DvaPoolData
    $DCSDVADEVICE=$DCSOBJECTMODEL.DataRepository.DvaPoolDeviceData
    $DCSDVADISK=$DCSOBJECTMODEL.DataRepository.DvaPoolDiskData
    $DCSDVAVOL=$DCSOBJECTMODEL.DataRepository.DvaPoolVolData
    $DCSPHYSICALDISK=$DCSOBJECTMODEL.DataRepository.PhysicalDiskData
    $DCSFCDATA=$DCSOBJECTMODEL.DataRepository.FcPortData
    $DCSFCCONNECTION=$DCSOBJECTMODEL.DataRepository.FcConnectionData
    $DCSSERVERFCPORT=$DCSOBJECTMODEL.DataRepository.ServerFcPortData



########################################################





 function zeTable ($VALUES,$PARAMS) {

    New-HTMLTable -PagingStyle full -ScrollX -DisablePaging -DisableOrdering -HideFooter -HideButtons -DisableInfo -DisableSearch -DataTable ($VALUES) $PARAMS

}

New-HTML -Name "Audit" -ShowHTML {

######Css like 
New-HTMLMain -BackgroundColor '#002D3F' -FontFamily 'Calibri' 
New-HTMLTableStyle -FontSize 20  -Type Header -TextAlign center -TextTransform uppercase 
New-HTMLTableStyle -FontSize 15  -Type Content -TextAlign center
TabOptions -BorderRadius 10px -SlimTabs -Transition -FontSize 20 -TextColor '#03BDBD' -FontWeight 200 -TextColorActive white -TextDecorationActive underline
New-HTMLTabOption -TextDecorationActive underline -Transition 

New-HTMLTabPanelColor -BackgrounColor '#002D3F'


   New-HTMLHeader {
        New-HTMLSection -Invisible -Direction column {
            New-HTMLPanel -Invisible -BackgroundColor '#002D3F' {
                New-HTMLImage -Source 'https://docs.datacore.com/RESTSupport-WebHelp/Skins/Fluid/Stylesheets/Images/datacore-logo-horizontal_209x69_trans_darkbkgr.png' -UrlLink 'https://datacore.com/' -AlternativeText 'DataCore' -Class 'otehr' -Width '10%'
                New-HTMLText -Text "Datacore Audit : $Cluster" -Color White -FontSize 20
            }
        }
    }
   New-HTMLFooter {
        New-HTMLSection -Invisible {
            New-HTMLPanel -Invisible -BackgroundColor '#002D3F' {
            New-HTMLText -Text " " -color white
                New-HTMLImage -Source 'https://s26500.pcdn.co/wp-content/uploads/2023/10/your-data-our-priority-badge-v2.svg' -UrlLink 'https://datacore.com/' -AlternativeText 'DataCore' -Class 'otehr' -Width '5%'

            }
        }
    }


    

   
    Tab -Name "About" -IconSolid check-circle  {
        $IMG="data:image/jpeg;base64,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"
        New-HTMLImage -Source $IMG -Width 95%
        New-HTMLText -Text "Health report version $HRVERSION" -color white -FontSize 15 
        New-HTMLText -Text "Collection time :  $COLLECTIONDATE" -color white -FontSize 15
        New-HTMLText -Text "DISCLAMER: This audit has been generated by a non official's DataCore script, take it as it is." -color yellow -FontSize 25 
        New-HTMLHorizontalLine 
        New-HTMLText -Text $ZELINK -FontSize 20
        $ZELINK=(New-HTMLLink -HrefLink "https://www.datacoreassets.com/resources/legal/DataCore-Data-Protection-Provisions-Addendum.pdf" -Text "GDPR")
    }

    Tab -Name "Audit" -IconSolid check-circle  {
    New-HTMLTabPanel -Orientation vertical -TransitionAnimation fade -Theme brick { 
        New-HTMLTab -Name "CLUSTER" -TextTransform capitalize -TextSize 20  {
            zetable ($VICLUSTER|select Name,HAEnabled,HAFailover,DrsEnabled,DrsAutomationLevel) {
                    New-HTMLTableStyle -Type Header -BackgroundColor '#03BDBD'
                    New-HTMLTableStyle -Type Content -BackgroundColor white
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor White -TextColor black -Type RowOdd
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor LightCyan -TextColor black -Type RowEven

                    New-HTMLTableCondition -Name "HAEnabled"  -ComparisonType string -Operator eq -Value "false"      -color white      -BackgroundColor orange 
                    }

            zeTable ($HACONFIG|select VmMonitoring,HostMonitoring,VmComponentProtecting,@{N="HeartbeatDatastore";E={$VAR=$_.HeartbeatDatastore;($DATASTORES|?{$_.id -in $VAR}).name}},HBDatastoreCandidatePolicy,option) {        
                    New-HTMLTableStyle -Type Header -BackgroundColor '#03BDBD'
                    New-HTMLTableStyle -Type Content -BackgroundColor white
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor White -TextColor black -Type RowOdd
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor LightCyan -TextColor black -Type RowEven

                    New-HTMLTableCondition -Name "HeartbeatDatastore"          -ComparisonType string -Operator eq -Value ""                     -color white               -BackgroundColor red 
                    New-HTMLTableCondition -Name "HBDatastoreCandidatePolicy"  -ComparisonType string -Operator ne -Value "userSelectedDs"       -color white               -BackgroundColor red 
                    New-HTMLTableCondition -Name "Option"                      -ComparisonType string -Operator eq -Value ""                     -color white               -BackgroundColor orange
                    }
            
            New-HTMLText -Text "
                Cluster, in case Hight Availability is 'Enabled' : <br>
                * a minimum of 2 dedicated single Datastore should be 'selected' for HA Storage Heartbeat <br>
                * special HA option could be set like 'isolationaddressXdas' to specify network Heartbeat target for HA <br>
                * <a href='https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere/7-0/vsphere-availability.html'>HA doc</a>
                " -FontSize 16 -Color White
            
            
            }
        New-HTMLTab -Name "ESX" -TextTransform capitalize -TextSize 20   {
        for ($k=0; $k -lt $VMHDETAILS_.count; $k++) {

                New-HTMLText -Text $($VMHDETAILS_[$k].VMhost) -FontSize 30 -Color '#009EF7'

                zeTable ($VMHDETAILS_[$k]){        
                    New-HTMLTableStyle -Type Header -BackgroundColor '#03BDBD'
                    New-HTMLTableStyle -Type Content -BackgroundColor white
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor White -TextColor black -Type RowOdd
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor LightCyan -TextColor black -Type RowEven
                    
                    New-HTMLTableCondition -Name "iSCSI DelayAck"  -ComparisonType string -Operator ne -Value "false"       -color white     -BackgroundColor red 
                    New-HTMLTableCondition -Name "iSCSI Alias"     -ComparisonType string -Operator eq -Value ""            -color white     -BackgroundColor red                                         
                    New-HTMLTableCondition -Name "iSCSI P.Binding" -ComparisonType string -Operator ne -Value ""            -color white     -BackgroundColor red                                         
                    New-HTMLTableCondition -Name "DiskMaxIOSize"   -ComparisonType string -Operator ne -Value "512"         -color white     -BackgroundColor red                                        
                    New-HTMLTableCondition -Name "NTPD"            -ComparisonType string -Operator eq -Value "Disabled"    -color white     -BackgroundColor red                                        
                    New-HTMLTableCondition -Name "SSHD"            -ComparisonType string -Operator ne -Value "Disabled"    -color white     -BackgroundColor orange                                        
                    New-HTMLTableCondition -Name "NTP Target"      -ComparisonType string -Operator eq -Value ""            -color white     -BackgroundColor red                                         
                    }
                New-HTMLText -Text "
                ESX nodes : <br>
                * should use iSCSI alias to make life easier <br>
                * will have iSCSI delayedack parameter disabled <br>
                * will NOT have any iSCSI network port binding <br>
                * will be set with the system advanded parameter / disk.diskmaxiosize to 512 instead of 32K <br>
                * will be sync with NTP servers<br>
                " -FontSize 16 -Color White


                zeTable ( $ISCSITARGETS_ | ?{$_.vmhost -match $VMHDETAILS_[$k].VMhost } ) {        
                    New-HTMLTableStyle -Type Header -BackgroundColor '#03BDBD'
                    New-HTMLTableStyle -Type Content -BackgroundColor white
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor White -TextColor black -Type RowOdd
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor LightCyan -TextColor black -Type RowEven
                    }




                zeTable ($DEVICES_ | ?{$_.vmhost -match $VMHDETAILS_[$k].VMhost } ) {        
                    New-HTMLTableStyle -Type Header -BackgroundColor '#03BDBD'
                    New-HTMLTableStyle -Type Content -BackgroundColor white
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor White -TextColor black -Type RowOdd
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor LightCyan -TextColor black -Type RowEven
                    
                    New-HTMLTableCondition -Name CommandsToSwitchPath -ComparisonType number -Operator lt -Value "10"          -color white  -BackgroundColor red
                    New-HTMLTableCondition -Name CommandsToSwitchPath -ComparisonType string -Operator eq -Value ""            -color white  -BackgroundColor red
                    New-HTMLTableCondition -Name BlocksToSwitchPath   -ComparisonType number -Operator lt -Value "10240"       -color white  -BackgroundColor red
                    New-HTMLTableCondition -Name BlocksToSwitchPath   -ComparisonType string -Operator eq -Value ""            -color white  -BackgroundColor red
                    New-HTMLTableCondition -Name Paths                -ComparisonType number -Operator lt -Value "4"           -color white  -BackgroundColor red
                    New-HTMLTableCondition -Name MultipathPolicy      -ComparisonType string -Operator ne -Value "RoundRobin"  -color white  -BackgroundColor red
                    
                    }
                New-HTMLText -Text "
                Storage devices should <br>
                * use RoundRobin Policy <br>
                * switch RR paths each 10 commands <br>
                * switch RR paths each 10K blocks <br>
                * have a minimum of 4 paths for mirrored vDisks <br>
                " -FontSize 16 -Color White

            New-HTMLHorizontalLine


            }
            }
        New-HTMLTab -Name "SSY" -TextTransform capitalize -TextSize 20  {
            for ($j=0; $j -lt $SSYDETAILS_.count; $j++) {
                New-HTMLText -Text $($SSYDETAILS_[$j].Name) -FontSize 30 -Color '#009EF7'
                zeTable $SSYDETAILS_[$j] {
                New-HTMLTableStyle -Type Header -BackgroundColor '#03BDBD'
                    New-HTMLTableStyle -Type Content -BackgroundColor white
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor White -TextColor black -Type RowOdd
                    New-HTMLTableStyle -FontFamily 'Calibri' -BackgroundColor LightCyan -TextColor black -Type RowEven
                    
                    New-HTMLTableCondition -Name "VM Latency"  -ComparisonType string -Operator ne -Value "high"         -color white  -BackgroundColor red
                    New-HTMLTableCondition -Name "CPU Res."    -ComparisonType string -Operator lt -Value "CPU Needs"    -color white  -BackgroundColor red 
                    New-HTMLTableCondition -Name "CPU"         -ComparisonType number -Operator lt -Value "4"            -color white  -BackgroundColor red
                    New-HTMLTableCondition -Name "Memory"      -ComparisonType number -Operator lt -Value "12"           -color white  -BackgroundColor red
                    New-HTMLTableCondition -Name "Memory Res." -ComparisonType string -Operator ne -Value "true"         -color white  -BackgroundColor red
                    New-HTMLTableCondition -Name "VMxnet3"     -ComparisonType number -Operator lt -Value "4"            -color white  -BackgroundColor red
                }

                New-HTMLText -Text "
                SANSymphony Virtual machine will run with <br>
                * a minimum of 4 vCPU, 100% reserverved (#core x GHz) <br>
                * a minimum of 12GB or memory, 100% reserved <br>
                * VM lantecy should be enabled <br>
                * 4 vNics type VMxnet3 for Mirror and FrontEnd's Ports <br>
                * SCSI controler for RDM disks will be 'ParaVirtual' type <br>
                " -FontSize 16 -Color White
            







                $SDS=$DCSSERVER| ? { $_.ipaddresses.string -match $SSY_[$j].ExtensionData.guest.IpAddress }
                $SDSID=$SDS.id




                    New-HTMLSection -HeaderText "DataCore server details" -CanCollapse -Collapsed  {
                        zeTable ($DCSSERVER |?{$_.caption -eq $SDS.caption}|select Caption,hostname,isVirtualMachine,PowerState,CacheState,IsLicensed,NextExpirationDate,ProductBuild,ProductVersion,State,GroupId) }                     #close section server detail
                    New-HTMLSection -HeaderText "Licences details" -CanCollapse -Collapsed  {
                        zeTable $($DCSOBJECTMODEL.DataRepository.ServerHostGroupData.ExistingProductKeys.ProductKeyData |? {$_.ServerId -eq $SDSID}|select ProductName,ExpirationDate,KeyType,LastFive,Suscription,IsBaseLicense)
                    }                  #close section  licenses
                    New-HTMLSection -HeaderText "Disk Pools" -CanCollapse -Collapsed -Direction row {

                        $DCSPOOL|?{ $_.ServerId -eq $SDSID} | %{
                            $DCSPOOL_=$_
                            New-HTMLSection -HeaderText $DCSPOOL_.Caption -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                New-HTMLSection -HeaderText "Pool details"  {
                                    zeTable $($DCSPOOL_ |?{$_.ServerId -eq $SDSID}|select Caption,PoolStatus,@{N="ChunkSize Mb";E={$_.chunksize.value/1MB}},@{N="SectorSize b";E={$_.SectorSize.value}},MaxTierNumber,TierReservedPct,IsAuthorized,InSharedMode,SMPAApproved,SupportsEncryption,DeduplicationState)
                                }
                                                        
                                $DATA=$PERFORMANCEDATA[$DCSPOOL_.id].Perf|Select-Object @{N="Allocated";E={[Math]::Round($_.BytesAllocated/1GB)}},@{N="Available";E={[Math]::Round($_.BytesAvailable/1GB)}},@{N="InReclamation";E={[Math]::Round($_.BytesInReclamation/1GB)}},@{N="Reserved";E={[Math]::Round($_.BytesReserved/1GB)}},@{N="Total";E={[Math]::Round($_.BytesTotal/1GB)}},@{N="OverSubscribed";E={[Math]::Round($_.BytesOverSubscribed/1GB)}},DeduplicationPoolUsedSpace,DeduplicationPoolFreeSpace,DeduplicationPoolTotalSpace
                                
                                New-HTMLSection -HeaderText "Graphic" -BackgroundColor white  {
                                    zeTable $($DATA | select Allocated,Available,InReclamation,Reserved,Total,OverSubscribed ) 
                                    New-HTMLChart -Gradient {
                                        New-ChartPie -Name Allocated -Value $DATA.allocated
                                        New-ChartPie -Name InReclamation -Value $DATA.InReclamation
                                        New-ChartPie -Name Reserved -Value $DATA.Reserved
                                        New-ChartPie -Name Available -Value $DATA.Available
                                        }
                                    }
                                }
                            }
                    }          #close section Pools
        
                    New-HTMLSection -HeaderText "Disk Pools Members" -CanCollapse  -Collapsed -Direction row{
                        $DCSPOOL|?{ $_.ServerId -eq $SDSID} | %{
                        $POOLCAPTION=$_.caption
                        $POOLID=$_.id
                        New-HTMLSection -HeaderText "$POOLCAPTION" -CanCollapse  -Collapsed -Direction row -HeaderBackGroundColor grey {
                         $zetablevalue=@($DCSPOOLMEMBER |?{$_.DiskPoolId -eq ${POOLID} -and $_.Caption -notlike "OpenZFS WinZVOL | *"}|select-object Caption,
                            DiskTier,
                            @{N="Size Gb";E={[Math]::Round($_.Size.value/1GB)}},
                            @{N="Allocated Gb";E={[Math]::Round($PERFORMANCEDATA[$_.id].perf.BytesAllocated/1Gb)}},
                            @{N="Allocated";E={[Math]::Round(($PERFORMANCEDATA[$_.id].perf.BytesAllocated)/($_.Size.value)*100)}},
                            @{N="SectorSize b";E={$_.SectorSize.value}},
                            IsMirrored,
                            MemberState,
                            @{N="CapacityOptimizedAllocated Gb";E={[Math]::Round($PERFORMANCEDATA[$_.id].perf.CapacityOptimizedBytesAllocated/1Gb)}},
                            @{N="OutOfAffinity Gb";E={[Math]::Round($PERFORMANCEDATA[$_.id].perf.BytesOutOfAffinity/1Gb)}}|sort-object -Property DiskTier)
                        zeTable $zetablevalue

                         


                            }
                        }
                    }   #close section Pool members



                    if ( $DCSDVAPOOL ) {

                    New-HTMLSection -HeaderText "Optimization Pools" -CanCollapse  -Collapsed -Direction row{
                        $DCSDVAPOOL|?{ $_.ServerId -eq $SDSID} | %{
                            $DCSDVAPOOL_=$_
                            zeTable $($PERFORMANCEDATA[$SDSID].perf|select @{N="DeduplucationRatio";E={([Math]::Round($_.DeduplicationRatioPercentage/100,2)).toString()+":1"}},
                                @{N="CompressionRatio";E={([Math]::Round($_.CompressionRatioPercentage/100,2)).toString()+":1"}},
                                @{N="OptimizationPoolUsage";E={ ([Math]::Round($_.DeduplicationPoolUsedSpace/1TB,2).ToString() + "TB/" + ([Math]::Round($_.DeduplicationPoolTotalSpace/1TB,2)).ToString() + "TB")}},
                                @{N="WithoutOptimization";E={([Math]::Round($_.ExpectedDeduplicationPoolUsedSpace/1TB,2).ToString()+"TB")}},
                                @{N="OptimizationPoolFree";E={([Math]::Round($_.DeduplicationPoolFreeSpace/1TB)).ToString()+"TB"}},
                                @{N="OptimizationPoolFree%";E={($_.DeduplicationPoolPercentFreeSpace).ToString()+"%"}},
                                @{N="L2ARCUsage";E={([Math]::Round($_.DeduplicationPoolL2ARCUsedSpace/1GB)).ToString()+ "GB/" +([Math]::Round($_.DeduplicationPoolL2ARCTotalSpace/1GB)).ToString() +"GB"}},
                                @{N="MirrorSpecialUsage";E={([Math]::Round($_.DeduplicationPoolSpecialMirrorUsedSpace/1GB,2)).ToString() + "GB/" + ([Math]::Round($_.DeduplicationPoolSpecialMirrorTotalSpace/1GB,2).ToString() + "GB")}}
                                )

                            zeTable $( $DCSDVADISK | ?{ $_.DvaPoolId -eq $DCSDVAPOOL_.ID} | select @{N="PhysicalDisk";E={$ZEID=$_.ID ; ($DCSPHYSICALDISK|?{$_.DvaPoolDiskId -eq $ZEID}).Alias}},
                                @{N="SizeGB";E={$ZEID=$_.ID ; [Math]::Round(($DCSPHYSICALDISK|?{$_.DvaPoolDiskId -eq $ZEID}).size.value/1GB) }},
                                @{N="SectorSize";E={$ZEID=$_.ID ; (($DCSPHYSICALDISK|?{$_.DvaPoolDiskId -eq $ZEID}).Sectorsize.value) }},
                                IsL2ARCDisk,
                                IsSpecialMirrorDisk,
                                @{N="RAID"; E={ if ( $_.IsL2ARCDisk -eq "false" -and $_.IsSpecialMirrorDisk -eq "false") { $DCSDVAPOOL_.RaidLevel } else {"-"}}} | Sort-Object 
                                )
                            }
                            
                        }  #close section ILDC
                    }                                                               #close test ILDC


                    New-HTMLSection -HeaderText "iSCSI Details" -CanCollapse -Collapsed  {
                        zeTable $($DCSISCSI | ? { $_.HostId -eq $SDSID} | select Caption,
                            @{N="IP";E={$_.PortConfigInfo.PortalsConfig.iScsiPortalConfigInfo.Address.Address+"/"+$_.PortConfigInfo.PortalsConfig.iScsiPortalConfigInfo.SubnetMask.Address}},
                            @{N="Role";E={$_.ServerPortProperties.role}},
                            Connected,
                            PresenceStatus,
                            AluaId,
                            PhysicalName,
                            PortName,
                            @{N="InitMaxCmds";E={$_.PortConfigInfo.MaxActiveICommands}},
                            @{N="TargetMaxCmds";E={$_.PortConfigInfo.MaxActiveTCommands}},
                            HbaNicProduct|sort-object -Property Caption,Role)  
                            }                    #close Section iSCSI

                    if ( $DCSSERVERFCPORT ) {
                    New-HTMLSection -HeaderText "FC Details" -CanCollapse -Collapsed  {
                        zeTable $($DCSSERVERFCPORT | ?{ $_.hostid -eq  $SDSID}| select Caption,
                            portname,
                            Connected,
                            @{N="Role";E={$_.ServerPortProperties.Role}},
                            @{N="SymbolicNodeName";E={$_.ServerPortProperties.SymbolicNodeName}},
                            @{N="ConnectionMode";E={$_.ServerPortProperties.ConnectionMode}},
                            @{N="DataRateMode";E={$_.ServerPortProperties.DataRateMode}},
                            @{N="DisablePortWhileStopped";E={$_.ServerPortProperties.DisablePortWhileStopped}}| sort-object -Property Role,Caption
                            )  
                            }                    #close Section FC
                            }
                            

          New-HTMLSection -HeaderText "OS Details" -CanCollapse -Collapsed -Direction row {
             
                            [xml]$OSDETAIL=(Get-ChildItem $TMPPATH -Filter $SDS.caption | sort-object -Property LastWriteTime -Descending | select -First 1)|Get-Content
                            New-HTMLSection -HeaderText "OS Details" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.System.Windowsdetails.$SDS | select CSName,Caption,InstallDate,LastBootUpTime) 
                                }
                            New-HTMLSection -HeaderText "Pagefile" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.Pagefile|select Name,InitialSize,MaximumSize ) 
                                }
                            New-HTMLSection -HeaderText "Memory Dump" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zetable $($OSDETAIL.Windows.MemoryDump|select DebugFilePath,DebugInfoType,AutoReboot,OverwriteExistingDebugFile,SendAdminAlert,WriteDebugInfo,WriteToSystemLog)  
                                }
                            New-HTMLSection -HeaderText "NTP" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zetable $($OSDETAIL.Windows.NTP|select Last_Successful_Sync_Time,Source) 
                                }
                            New-HTMLSection -HeaderText "etc/hosts" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.etchosts.ChildNodes|select IP,HostName) 
                                }
                            New-HTMLSection -HeaderText "Physical Disks" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.PhysicalDisk.ChildNodes|select DeviceId,
                                MediaType,
                                FriendlyName,
                                SerialNumber,
                                @{N="Size Gb";E={[Math]::Round($_.Size/1GB)}} | 
                                sort-object DeviceId) 
                                }
                            New-HTMLSection -HeaderText "Volumes" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zetable $($OSDETAIL.Windows.Volumes.ChildNodes|select DriveLetter,
                                HealthStatus,
                                OperationalStatus,
                                @{N="Size Gb";E={[Math]::Round($_.Size/1GB)}},
                                @{N="SizeRemaining Gb";E={[Math]::Round($_.SizeRemaining/1GB)}},
                                AllocationUnitSize) 
                                }
                            New-HTMLSection -HeaderText "Network Interfaces" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.Netadapter.ChildNodes|select Name,MediaConnectionState,Status,IP,MacAddress,LinkSpeed,MtuSize,InterfaceName,InterfaceIndex,InterfaceDescription,DriverProvider,DriverVersion) 
                                }
                            New-HTMLSection -HeaderText "Network Binding" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.NetadapterBinding.ChildNodes|select ifAlias,
                                Internet_Protocol_Version_4__TCP_IPv4_,
                                Internet_Protocol_Version_6__TCP_IPv6_,
                                Client_for_Microsoft_Networks,
                                File_and_Printer_Sharing_for_Microsoft_Networks,
                                Link-Layer_Topology_Discovery_Mapper_I_O_Driver,
                                Link-Layer_Topology_Discovery_Responder,
                                Microsoft_LLDP_Protocol_Driver,
                                Microsoft_Network_Adapter_Multiplexor_Protocol,
                                QoS_Packet_Scheduler )
                                }
                            New-HTMLSection -HeaderText "Network Advanced Properties" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zetable $($OSDETAIL.Windows.NetAdapterAdvancedProperty.ChildNodes|select ifAlias,
                                Interrupt_Moderation,
                                IPv4_Checksum_Offload,
                                IPv4_TSO_Offload,
                                Large_Send_Offload_V2__IPv4_,
                                Offload_IP_Options,
                                Receive_Throttle_for_NDIS_ALL,
                                Rx_Ring__1_Size,
                                Small_Rx_Buffers,
                                TCP_Checksum_Offload__IPv4_,
                                Tx_Ring_Size,VLAN_ID,Jumbo_Packet)
                                }
                            New-HTMLSection -HeaderText "iSCSI Connections" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zetable $($OSDETAIL.Windows.iSCSIConnection.iSCSIconnections.ChildNodes|select ConnectionIdentifier,InitiatorAddress,InitiatorPortNumber,TargetAddress,TargetPortNumber ) 
                                }
                            New-HTMLSection -HeaderText "Installed Software" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.Software.InstalledSoftware.ChildNodes|select DisplayName,DisplayVersion,InstallDate|sort-object -Property InstallDate -Descending) 
                                }
                            New-HTMLSection -HeaderText "Windows Update" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.WindowsUpdate.WindowsUpdate.ChildNodes|select HotFixID,Description,InstalledOn,Caption|sort-object -Property InstalledOn -Descending ) 
                                }
                            New-HTMLSection -HeaderText "EventLogs - Last reboots & crashs" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.EventLog.Reboot_and_Crash.ChildNodes |select TimeGenerated,EntryType,Source,InstanceId,Message|sort-object -Property TimeGenerated) 
                                }
                            New-HTMLSection -HeaderText "EventLogs - last 100 errors" -CanCollapse -Collapsed -Direction row -HeaderBackGroundColor grey {
                                zeTable $($OSDETAIL.Windows.EventLog.Last100.ChildNodes|select TimeGenerated,EntryType,Source,InstanceId,Message|sort-object -Property TimeGenerated) 
                                }

                            }
                            #close Section OS Detail 
                
            }





            }
 
 
 
        }
    }

} -FilePath "./htdocs/index.html"





