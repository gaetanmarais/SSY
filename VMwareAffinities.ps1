######################################################
##
##  Script : VMware affinities
##
##
##  This script is used to check affinities between VMs, ESXs and DataStores
##  All VMs running on even ESX (last caracter) need to be hosted on even DataStore (last caracter) 
##  All VMs running on odd  ESX (last caracter) need to be hosted on odd  DataStore (last caracter) 
##
##  If a VM is not compliant with this rule, VMotion is operate (if doVomotion variable is set to 1)
##  If a VM is hosted in multiple DataStore across both DataCenter, nothing is done and an error message is show
##
##  This script is based on VMware's RESTAPI
##
##  Author : gaetan MARAIS
##  Date   : 2025/03/31
##
######################################################


# Variables
$vcenter = "vcenter510.datacore.paris"
$username = "administrator@vsphere.local"
$password = "Datacore1!"

# doVmotion   0=No vMotion, 1=Auto, 2=Ask
$doVmotion = 1      # 


# DataCenter definition  
# DC1 VM and Storage need a latest oven caracter 
# DC2 VM and Storage need a latest odd caracter
$VMhostsDC1=@('\d*[13579]$')
$VMhostsDC2=@('\d*[02468]$')
$DataStoreDC1=@('\d*[13579]$')
$DataStoreDC2=@('\d*[02468]$')

$testREG=@('\d*[0123456789]$')

# Disable SSL check
if (-not ("TrustAllCertsPolicy" -as [type])) {
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
}
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12




# Connect to vCenter and get session token 

    Write-Host "Connection to vCenter: $vcenter"

    $authResponse = Invoke-RestMethod -Uri "https://$vcenter/rest/com/vmware/cis/session" -Method Post -Headers @{"Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$password")))"} 
    if (-not $authResponse.value) {
        Write-Host "Échec de l'authentification ! Vérifiez vos identifiants."
        exit 1
    }
    $sessionId = $authResponse.value
    $authHeader = @{ "vmware-api-session-id" = $sessionId }
    
    Write-Host "Connection OK, session ID collected"

# Get Host list
Write-Host "Gather ESX Host list"
$hostsResponse = Invoke-RestMethod -Uri "https://$vcenter/rest/vcenter/host" -Method Get -Headers $authHeader
if (-not $hostsResponse.value) {
    Write-Host "No ESX collected ???!!!."
    exit 1
}
$vmhosts = $HostsResponse.value

$vmInfoList = @()
foreach ($vmhost in $vmhosts) {
    $vmhostid = $vmhost.host
    $vmhostname = $vmhost.name
    # Collect VM list by ESX
    Write-Host "Gather VM list for ESX $vmhostname"
    $vmsResponse = Invoke-RestMethod -Uri "https://$vcenter/rest/vcenter/vm?filter.hosts=$vmhostid" -Method Get -Headers $authHeader
    if (-not $vmsResponse.value) {
        Write-Host "No VMs for $vmhostname"
    }
    $vms = $vmsResponse.value

    # Gather VM details
    
    foreach ($vm in $vms) {
        $VMID=$VM.vm
        $vmDetails = Invoke-RestMethod -Uri "https://$vcenter/rest/vcenter/vm/$VMID" -Method Get -Headers $authHeader
        if (-not $vmDetails.value) {
            Write-Host "Unable to gather details for VM $($vm.vm)"
            continue
        }
        $vmName = $vmDetails.value.name
        $vmState = $vmDetails.value.power_state
        
        # Gather Datastore details by VM
        $vmStorage = Invoke-RestMethod -Uri "https://$vcenter/rest/vcenter/vm/$($vm.vm)/hardware/disk" -Method Get -Headers $authHeader
        $datastores = @()
        if ($vmStorage.value) {
            foreach ($disk in $vmStorage.value.disk) {
                $dsDetails = Invoke-RestMethod -Uri "https://$vcenter/rest/vcenter/vm/$($vm.vm)/hardware/disk/$disk" -Method Get -Headers $authHeader
                    if ($dsDetails.value) {
                        $datastores += (((($dsDetails.value.backing.vmdk_file).Split())[0]).replace("[","")).replace("]","")
                        }
                    }
                }
    
        if (-not $datastores) { $datastores = @("Aucun") }


    # Assign DataCenter to VM
    if ( $vmhostname -match $VMhostsDC1 ) { $VMDC="DataCenter1" }
    elseif ( $vmhostname -match $VMhostsDC2 ) { $VMDC="DataCenter2" }
    else { $VMDC="NotListed"}

    # Assign DataCenter to DataStore
    $DSDC=@()
    foreach ( $datastore in $datastores) {
        if ( $datastore -match $DataStoreDC1 ) { $DSDC+="DataCenter1" }
        elseif ( $datastore -match $DataStoreDC2 ) { $DSDC+="DataCenter2" }
        else { $DSDC+="NotListed"}
    }

   
    #check for Need_Vmotion
    if ( ( $DSDC -eq "NotListed") -or ( $VMDC -eq "NotListed") ) { $VMOTION="N-A" }
    elseif ( ($DSDC|select -unique).Count -gt 1 ) { $VMOTION="SPLIT" }
    elseif ( $DSDC -eq $VMDC ) { $VMOTION="NO"}
    else { $VMOTION="YES"}
    
    # Create the Array with all the collected information
    $vmInfoList += [PSCustomObject]@{
        VM_Name    = $vmName
        VM_Id    = $vmID
        Host_Name  = $vmhostName
        DataCenter_VM = $VMDC
        VM_Status  = $vmState
        Datastores = ($datastores | select -Unique) -join ","
        DataCenter_DS = ($DSDC | select -Unique) -join ","
        Vmotion_Needed = $VMOTION

    }
}
}

$list=$vmInfoList| ? {$_.vMotion_needed -eq "NO" }
if ( $list.count -ne 0 ) {
    # Show the result : correct placement
    write-host -ForegroundColor green "These VMs are correctly placed"
    $list |ft 
}

$List=$vmInfoList| ? {$_.vMotion_needed -eq "SPLIT" }
if ( $list.count -ne 0 ) {
    # Show the result : placement can not be changed, multiple storage aon oth DataCenter for same VM
    write-host -ForegroundColor red "These VMs are using multiple storages cross to both DataCenter, can cause SplitBrain"
    write-host -ForegroundColor yellow "Manual Storage vMotion would be done to fix the potential issue"
    $list |ft
}



$List=$vmInfoList| ? {$_.vMotion_needed -eq "N-A" }
if ( $list.count -ne 0 ) {
    # Show the result : 
    write-host -ForegroundColor yellow "No Action will be take for these VMs as the ESX hosts or DataStore are not compliant with the script RegEx variables"
    $list |ft
}




$list = $vmInfoList| ? {$_.Vmotion_Needed -eq "YES" }
if ( $list.count -ne 0) {
    # Vmotion
    if ( $doVmotion -eq 0 ) {
        Write-Host -ForegroundColor red "This script is not configured to execute vMotion"
        Write-Host -ForegroundColor yellow "Following VM can introduce otential split-brain, execute manual vmotion to fix it"
        $list | ft
    }

    # vMotion ON 
    elseif ( $doVmotion -eq 1 ) {

        Write-Host -ForegroundColor yellow "Following VM need vMotion to avoid potential SplitBrain"
        $List | ft
        
        Write-Host -ForegroundColor yellow "vMotion in progress..."    
        $List | % {
        $line=$_

        if ( $Line.DataCenter_VM -eq "DataCenter1" ) {
            $nexthost=Get-Random -InputObject ($vmhosts | ? {$_.name -match $VMhostsDC2 }) 
             }
        else {
            $nexthost=Get-Random -InputObject ($vmhosts | ? {$_.name -match $VMhostsDC1 })
        }

        $body = @{
            spec = @{
                placement = @{
                    host = $nexthost.host
                    }
                }
            } | ConvertTo-Json -Depth 10

        $vmotionResponse=Invoke-RestMethod -Method Post -Uri "https://$vcenter/rest/vcenter/vm/$($line.vm_id)?action=relocate" -Headers $authHeader -Body $body -ContentType "application/json"
        write-host "vMotion done for $($line.VM_Name) to $($nexthost.name)"
        }
    }    

}

# Disconnected from vCenter
Invoke-RestMethod -Uri "https://$vcenter/rest/com/vmware/cis/session" -Method Delete -Headers $authHeader
