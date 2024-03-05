################################################################
################################################################
################################################################
##
## 
##
##
## Author  : Gaetan MARAIS 
## Company : DataCore
##
## version : 2.0
## date    : 2020/09/29
## Note    : install and config as function
##
##         : Spare disk have to be renommed using "SPARE-Tx_blablabla"
##         : Tx is the Tier number
##


<#
.SYNOPSIS
    .
.DESCRIPTION
    .
.PARAMETER
    install [boolean]
    help [switch]
.SYNTAX
    Run the script
        C:\Program files\DataCore\SANSymphony\Auto_Repair_disk_NVMe.ps1

    Install the script as a task
        C:\Program files\DataCore\SANSymphony\Auto_Repair_disk_NVMe.ps1 -install

    
.NOTES
    Author: Gaëtan MARAIS
    Date:   2020.09.28
    Version : 2.0
#>

Param(
    [Parameter(Mandatory = $false, HelpMessage="Install script & DataCore task.")]
	[switch]
    $Install,
    [Parameter(Mandatory = $false, HelpMessage="This help message")]
	[switch]
    $help,
    [Parameter(Mandatory = $false, HelpMessage="Disk pool in trouble")]
    [string]
    $DiskPools  
)

# Get the installation path of SANsymphonyV
$bpKey = 'BaseProductKey'
$regKey = Get-Item "HKLM:\Software\DataCore\Executive"
$strProductKey = $regKey.getValue($bpKey)
$regKey = Get-Item "HKLM:\$strProductKey"
$installPath = $regKey.getValue('InstallPath')





#Parameters
##################################################
$server = $env:COMPUTERNAME
$ScriptName = "Auto-Repair-Disk"


$Time2Wait = 1#60*10    #10 minutes
$ForcePurge = 1       #0 Purge will not be executed if dataloss (snap)

$eventlogsource = $scriptname

################################################################
################################################################
################################################################
# Functions



function showhelp {

write-host "
    HELP
    Run the script
        $($MyInvocation.ScriptName)

    Install the script as a SSY task
        $($MyInvocation.ScriptName) -install 

    Show this help
        $($MyInvocation.ScriptName) -help
    "
    exit

    }

function Connect-DataCore-server {
try {Import-Module "$installPath\DataCore.Executive.Cmdlets.dll" -DisableNameChecking -ErrorAction Stop}
catch {
    $ErrorMessage = $_.Exception.Message
    $logmsg="
    Unable to load Import the DataCore commandelt module - $installPath\DataCore.Executive.Cmdlets.dll

    $ErrorMessage"
    Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 1 -Category 0 -Message $logmsg
    exit 100
    }


try {Connect-DcsServer}
catch {
    $ErrorMessage = $_.Exception.Message
    $logmsg="
    Unable to connect DataCore server over powershell

    $ErrorMessage"
    Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 2 -Category 0 -Message $logmsg
    exit 100
}

}



function install-script {


# Copy script on DataCore install folder
    $scriptinstallpath="\\$server\$($installPath -replace(':','$'))\$ScriptName.ps1"
    Add-DcsLogMessage -Level Info -Message "$scriptname : Installation of the $ScriptName script/task on $server"
    try { copy-item -Destination $scriptinstallpath $MyInvocation.ScriptName -Force }
    catch {
        $msglog = "Script installation error: Unable to copy the script into the SSY folder : $scriptinstallpath
        "
        Write-Host $msglog
        $ErrorMessage = $_.Exception.Message
        Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 10 -Category 0 -Message "
        $msglog

        $errorMessage"
        Add-DcsLogMessage -Level Error -Message "$scriptname : FAILED - Installation of the $ScriptName script/task on $server"
    }


    if (get-dcstask -Task $ScriptName ) {Remove-DcsTask -Task $ScriptName | out-null  } 

    Add-DcsTask -name $ScriptName  | out-null
    Add-DcsTrigger -Task $scriptname -Description "eee" -TemplateTypeId "T(DataCore.Executive.Controller.DiskPoolStateMonitor<DataCore.Executive.Controller.DiskPool>)" -MonitorState Critical -Comparison "="
    Add-DcsAction  -Task $ScriptName -Server $server  -FilePath "$installPath\$ScriptName.ps1" -ScriptAction PowerShell | out-null

    write-host "$ScriptName task auto created for server $server "
    Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Information –EventID 10 -Category 0 -Message "
        SSY task $ScriptName created successfuly
            installation on server : $server
            script path : $scriptinstallPath
        "

read-host -prompt "[press enter]"


}





Connect-DataCore-server

#Show help script
if ( $help) { showhelp }    

#Create new source on application Eventlog
New-EventLog -ComputerName $server  -LogName Application -Source $eventlogsource -ErrorAction SilentlyContinue
       
#Install & configure
if ($install) {Install-Script}




Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Warning –EventID 10 -Category 0 -Message "Pool Offline - wait for $Time2wait secs."
Add-DcsLogMessage -Level Warning -Message "$ScriptName : Pool Offline - wait for $Time2wait secs."


sleep $Time2Wait




#starting to enumerate disk pool
 Get-DcsPool |  % {
 $diskpool=$_.id
 $diskpoolcaption=$_.Caption

#Detect disk issue
##################################################
$baddisk=(Get-DcsPhysicalDisk -Type PoolDisk -Pool $diskpool | ? {$_.DiskStatus -eq "Failed"})
$baddiskalias=$($baddisk).caption
$baddiskid=$baddisk.id


#No disk failed
if ( $baddisk.count -eq 0 ) {  return }

#One disk is failed
if ( $baddisk.count -eq 1 )
    {
        $baddiskpool=(Get-DcsPoolMember -PoolMember $baddisk.PoolMemberId)
        $baddisktier=$baddiskpool.disktier
        $baddisksize=$baddiskpool.Size
        $baddisksector=$baddiskpool.SectorSize
        $baddiskserver=(get-dcsserver | ? { $_.Id -eq $baddisk.hostid }).caption
        $baddiskpool=(get-dcspool | ? { $_.Id -eq $baddiskpool.diskpoolid }).caption


         

        $messagelog="
Disk issue : $baddiskalias
--Server   : $baddiskserver
--Pool     : $baddiskpool
--Id     # : $baddiskid
--Tier   # : $baddisktier
--Size   # : $baddisksize
--Sector # : $baddisksector"

        #Check for Purge prerequerites
        ############################################

        $purgeprereqs=$baddisk.Id|Get-DcsPurgePrerequisites

        if ($purgeprereqs.count -eq 0)
            {
            $messagelog+="
======================================================
Purge Action : NO-PREREQUISITE"
            }
        else 
            {
                $messagelog+="
======================================================
Purge Action : PRE-REQUISITES NEEDED"
                $action=0
                $purgeprereqs | % { $messagelog+="`n$(get-dcsvirtualdisk -VirtualDisk $_.id) ==> $($_.actions)"
                                    if ($_.actions -ne "None") {$action=1}
                                    }
                if ($action -eq 0) {
                    
                    $messagelog+="`n`nNO ACTION REQUIRED"
                    Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Warning –EventID 10 -Category 0 -Message $messagelog
                    Add-DcsLogMessage -Level Warning -Message "$ScriptName : $messagelog"
                    }
                else {
                    $messagelog+="`n`nACTION(S) ARE REQUIRED, SCRIPT STOP!!!"
                    Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 10 -Category 0 -Message $messagelog
                    Add-DcsLogMessage -Level error -Message "$ScriptName : $messagelog"
                    exit 10
                    }
                }
        
        
        #Purge the disk
        ############################################
        if ( $ForcePurge -eq 0 ) { $baddisk.Id|Purge-DcsPoolMember}
        else {
            try {$baddisk.Id|Purge-DcsPoolMember -AllowDataLoss}
            catch {
                    $ErrorMessage = $_.Exception.Message
                    $messagelog="Unable to purge failed disk
                    $ErrorMessage"
                    Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 10 -Category 0 -Message $messagelog
                    Add-DcsLogMessage -Level error -Message "$ScriptName : $messagelog"
                    exit 10
                    }


            # Remove the comment below if you want to delete the failed disk from the inventory
            # if ($baddisk.alias) { Set-DcsPhysicalDiskProperties -Disk $baddiskid -NewName ""| Out-Null }
            
            }

        $availabledisk=Get-DcsPhysicalDisk -Available -Server $baddiskserver | sort -Property Size | ? {$_.size -ge $baddisksize -and $_.SectorSize -eq $baddisksector -and $_.caption -like "SPARE-T$baddisktier*"}|Select-Object -first 1
        $availablediskcaption=($availabledisk.caption).replace("SPARE-T$baddisktier","").TrimStart('_',' ','-')

        if ($availabledisk.count -eq 0) 
            {
            $messagelog="No Spare disk available to add into the pool"
            Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 12 -Category 0 -Message $messagelog
            Add-DcsLogMessage -Level error -Message "$ScriptName : $messagelog"
            }
        else
            {
            try {$newdisk=Add-DcsPoolMember -Pool $baddiskpool -Disk $availabledisk
                    $messagelog="New disk added into the pool`n--Disk Name : $availabledisk`n--Pool Name : $baddiskpool"}
            catch {
                    $ErrorMessage = $_.Exception.Message
                    $messagelog="Unable to add disk on pool
                    $ErrorMessage"
                    Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 12 -Category 0 -Message $messagelog
                    Add-DcsLogMessage -Level error -Message "$ScriptName : $messagelog"
                    exit 12
                    }



            try {Set-DcsPoolMemberProperties -PoolMember $newdisk.Id -DiskTier $baddisktier | Out-Null
            $messagelog+="`n--Tier #    : $baddisktier"}
            catch {
                    $ErrorMessage = $_.Exception.Message
                    $messagelog="Unable to change tier level for the disk
                    $ErrorMessage"
                    Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 12 -Category 0 -Message $messagelog
                    Add-DcsLogMessage -Level error -Message "$ScriptName : $messagelog"
                    }



            try {Set-DcsPhysicalDiskProperties -Disk $newdisk.id -NewName "$availablediskcaption ($baddiskalias)"| Out-Null
            $messagelog+="`n--Disk renamed to : $availablediskcaption ($baddiskalias)"
            Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType warning –EventID 1 -Category 0 -Message $messagelog
            Add-DcsLogMessage -Level Warning -Message "$ScriptName : $messagelog"
            }
            catch {
                    $ErrorMessage = $_.Exception.Message
                    $messagelog="Unable to rename the disk with $availablediskcaption ($baddiskalias)
                    $ErrorMessage"
                    Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 12 -Category 0 -Message $messagelog
                    Add-DcsLogMessage -Level error -Message "$ScriptName : $messagelog"
                    }
            }
        

}        

        
    
else
    {
    #More than 1 disk failed, we break the script
    if ($baddisk.count -ne 0) {
        $messagelog="Too many disks failed on pool disk : $diskpoolcaption
        No replace will be operate
        Disk failed : $baddisk"
        Write-EventLog -ComputerName $server –LogName Application –Source $eventlogsource –EntryType Error –EventID 20 -Category 0 -Message $messagelog
        Add-DcsLogMessage -Level error -Message "$ScriptName : $messagelog"
        }
    else {
            # NO DISK FAILED
            {return}
        }
    }



}