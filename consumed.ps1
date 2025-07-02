#
#Source file is a TXT file with semi-colomn separators for server;user;password
#  10.12.13.14;Administrator;Password!!!
#
#source file need only 1 node per DataCore group !!!
#

$SOURCE="C:\Users\gmarais\OneDrive - DataCore Software Corporation\Desktop\Scripts\SSY\list.txt"
$DESTINATION=$SOURCE+".csv"


$LIST=Get-Content -Path $SOURCE

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

        Write-Host "TrustAllCertsPolicy type added." -ForegroundColor White
      }
    catch
    {
        Write-Host $_ -ForegroundColor "Yellow"
    }

    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

Ignore-SelfSignedCerts


$global:array = @()
$i=1


$LIST|sort | % {
if ( $_ -like "#*" -or [string]::IsNullOrEmpty($_) ) {return}

$server=$($_ -split";")[0]
$dcsuser=$($_ -split";")[1]
$dcspwd=$($_ -split";")[2]


$LicenceType=@("Regular","Trial","NFR","Cloud","AzurePayGo")

 $headers = @{}
 $headers.Add("ServerHost", $server)
 $headers.Add("Authorization", "Basic $dcsuser $dcspwd")
 $ERR=0


 try
    {
    $GLOBAL:POOLSPERF=""
    $GLOBAL:SERVERS=$(Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/servers)
    $GLOBAL:GROUPS=$(Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/ServerGroups)

    while ( !($POOLSPERF) ) {
        $GLOBAL:POOLSPERF=$(Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$server/RestService/rest.svc/1.0/performancebytype/DiskPoolPerformance)
        sleep 1 
        }
   
    }
catch
    {
    $ERR=1
    Write-Host "Error Gathering server : $server -- $_" -BackgroundColor Red
    }

if ( $ERR -ne 1 ) { 

$servers | % {
 $SERVER_=$_
 $SERVERID=$SERVER_.id
 $SERVERDATA=(($groups).ExistingProductKeys | ? { $_.serverId -eq $SERVERID})
 $GROUPDATA=(($groups).LicenseSettings)
 $POOLDATA=($POOLSPERF | ? { $_.ObjectId -like $SERVERID+"*" })

 $PoolsAllocated=$([math]::Round($((($POOLDATA).PerformanceData.BytesAllocated|Measure-Object -Sum).sum/1TB),2)) 
 $PoolsAvailabe=$([math]::Round($((($POOLDATA).PerformanceData.BytesAvailable|Measure-Object -Sum).sum/1TB),2))
 $PoolsTotal=$PoolsAllocated+$PoolsAvailabe

 $object = New-Object -TypeName PSObject
 $object | Add-Member -Name '#' -MemberType Noteproperty -Value $i
 $object | Add-Member -Name 'Group' -MemberType Noteproperty -Value $groups.alias
 $object | Add-Member -Name 'Group_ID' -MemberType Noteproperty -Value $groups.id
 $object | Add-Member -Name 'HostName' -MemberType Noteproperty -Value $SERVER_.HostName
 $object | Add-Member -Name 'SSY_Node' -MemberType Noteproperty -Value $SERVER_.CAPTION
 $object | Add-Member -Name 'SSY_Version' -MemberType Noteproperty -Value $SERVER_.ProductVersion
 $object | Add-Member -Name 'OsVersion' -MemberType Noteproperty -Value $SERVER_.OSVERSION
 $object | Add-Member -Name 'Hardware' -MemberType Noteproperty -Value $SERVER_.ProcessorInfo.ProcessorName
 $object | Add-Member -Name 'Cores' -MemberType Noteproperty -Value $SERVER_.ProcessorInfo.NumberCores
 $object | Add-Member -Name 'Lic_type' -MemberType Noteproperty -Value $LicenceType[$groups.LicenseType]
 $object | Add-Member -Name 'Lic_name' -MemberType Noteproperty -Value $(if ( (($groups).ExistingProductKeys | ? { $_.serverId -eq $SERVERID}) ) { $serverdata.Label } else { ($groups).ExistingProductKeys.label })
 $object | Add-Member -Name 'Lic_keys' -MemberType Noteproperty -Value $(if ( (($groups).ExistingProductKeys | ? { $_.serverId -eq $SERVERID}) ) { $($serverdata.LastFive -join",") } else { ($groups).ExistingProductKeys.lastfive }) 
 $object | Add-Member -Name 'Lic_Capacity' -MemberType Noteproperty -Value $(($serverdata.capacity.value|Measure-Object -Sum).sum/1TB)
 $object | Add-Member -Name 'Lic_Actual_Capacity' -MemberType Noteproperty -Value $(($serverdata.actualcapacity.value|Measure-Object -Sum).sum/1TB)
 $object | Add-Member -Name 'Lic_Consumed_Capacity' -MemberType Noteproperty -Value $(($serverdata.capacityConsumed.value|Measure-Object -Sum).sum/1TB)
 $object | Add-Member -Name 'Lic_Group_Capacity' -MemberType Noteproperty -Value $([math]::Round($(($groupdata.StorageCapacity.value|Measure-Object -Sum).sum/1TB),2))
 $object | Add-Member -Name 'Expiration_Date' -MemberType Noteproperty -Value $groups.NextExpirationDate
 $object | Add-Member -Name 'Days remaining' -MemberType NoteProperty -Value (New-TimeSpan -start $(Get-Date) -end $groups.NextExpirationDate).days
 
 $object | Add-Member -Name 'Pools_Storage_Allocated' -MemberType Noteproperty -Value $PoolsAllocated
 $object | Add-Member -Name 'Pools_Storage_Available' -MemberType Noteproperty -Value $PoolsAvailabe
 $object | Add-Member -Name 'Pools_Storage_Total' -MemberType Noteproperty -Value $PoolsTotal
 $object | Add-Member -Name 'Pools_Total_OverSubscription' -MemberType Noteproperty -Value $([math]::Round($((($POOLDATA).PerformanceData.BytesOverSubscribed|Measure-Object -Sum).sum/1TB),2))
 
 ($GROUPDATA | gm -MemberType NoteProperty).Name | % {
    $NoteProperty=$_
    $object | Add-Member -Name $NoteProperty -MemberType NoteProperty -Value $GROUPDATA.$NoteProperty
 }
 
 $array += $object
 
 }



 }
 $i++
}


 $array | Export-Csv $DESTINATION -NoTypeInformation
