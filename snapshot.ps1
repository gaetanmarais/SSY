###################################################################################################################################
###################################################################################################################################
####
#### SANSYMPHONY - create snapshot and serve it to selected hosts
####
####
#### Author     : Gaetan MARAIS
#### Date       : 
####
####
#### Version    : 
####              
####
####
####
####
###################################################################################################################################
###################################################################################################################################


function Ignore-SelfSignedCerts
{
    try
    {
        Write-Host "Adding TrustAllCertsPolicy type." -ForegroundColor White
        Add-Type -TypeDefinition  @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy
        {
             public bool CheckValidationResult(
             ServicePoint srvPoint, X509Certificate certificate,
             WebRequest request, int certificateProblem)
             {
                 return true;
            }
        }
"@

#        Write-Host "TrustAllCertsPolicy type added." -ForegroundColor White
      }
    catch
    {
        Write-Host $_ -ForegroundColor "Yellow"
    }

    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

Ignore-SelfSignedCerts


$global:array = @()
$i=0


$global:server="10.12.106.21"
$global:dcsuser="Administrator"
$global:dcspwd=Read-Host -assecurestring "Please enter the $server\$dcsuser's password"



 $headers = @{}
 $headers.Add("ServerHost", $server)
 $headers.Add("Authorization", "Basic $dcsuser $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($dcspwd)))")
 $ERR=0

 $GLOBAL:POOLS=$(Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/pools)
 $GLOBAL:VDISKS=$(Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/virtualdisks)
 $TABLE=@()
$vdisks|%{
    $SPOOLID=$_.SnapShotPoolId
    $OBJ = New-Object Psobject
    $OBJ | Add-Member -Name "ID" -membertype Noteproperty -Value $_.id
    $OBJ | Add-Member -Name "VirtualDisk" -membertype Noteproperty -Value $_.caption
    $OBJ | Add-Member -Name "Type" -membertype Noteproperty -Value $_.type
    $OBJ | Add-Member -Name "Size" -membertype Noteproperty -Value $([math]::round(($_.size.value/1GB)))
    $OBJ | Add-Member -Name "SnapShotPool" -membertype Noteproperty -Value ($POOLS| ? {$_.id -eq $SPOOLID}).ExtendedCaption
    $OBJ | Add-Member -Name "SnapshotPoolID" -membertype Noteproperty -Value $SPOOLID
    $TABLE += $OBJ
    
 }

 $SELECTEDVDS=($TABLE | out-gridview -title "Select Virtual disks you want to take a snapshot" -PassThru)


 $SELECTEDVDS | %{

 $VD=$_.VirtualDisk
 $VDID=$_.id
 if ( ! $_.SnapShotPoolID ) {
 $SNAPPOOL=(Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/pools)
 $SNAPPOOLID=(($SNAPPOOL|Select-Object ExtendedCaption,id| Out-GridView -Title "Select Snapshot Pool for $VD" -PassThru )|select -First 1 ).id
 }
 else { $SNAPPOOLID=$_.SnapShotPoolID}

 $DATE=Get-Date -UFormat "%y%m%d%H%M%S"
 $PARAMS = @{
        "Name"="""$VD - $DATE""";
        "VirtualDisk"="$VDID";
        "DestinationPool"="$SNAPPOOLID";
        "Type"="0"
         }

 try {(Invoke-RestMethod -TimeoutSec 15 -Method POST -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/snapshots -Body ($PARAMS|ConvertTo-Json)) }
 catch { 
    [System.Windows.MessageBox]::Show("Unable create Snapshot for $VD : $Error[0]")
    break
    }
 $SNAPID=((Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/virtualdisks)|?{$_.Caption -eq """$VD - $DATE"""}).id

 
 $HOSTS=((Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/hosts) | ? {$_.state -eq 2}|Select-Object Caption,Description,id| Out-GridView -Title "Select Hosts to serve vDisk $VD" -PassThru)

 $HOSTS|%{
    $PARAMS = @{
        "Operation"="Serve";
        "Host"="$($_.id)";
        "Redundancy"="true"
         }

    try{Invoke-RestMethod -TimeoutSec 15 -Method POST -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/virtualdisks/$SNAPID -Body ($PARAMS|ConvertTo-Json)}
    catch {
        [System.Windows.MessageBox]::Show("Unable to serve $VD : $Error[0]")
        }
    }
 }