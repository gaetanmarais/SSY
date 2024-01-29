###################################################################################################################################
###################################################################################################################################
####
#### SANSYMPHONY - This script is used from UPS devices to stop/start virtualization and Enable/Disable Cache
####
#### Author     : Gaetan MARAIS
#### Date       : 2024/01/29
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
<#

.SYNOPSIS
        This script is used from UPS devices to stop/start virtualization and Enable/Disable Cache 

.DESCRIPTION
        This script is used from UPS devices to stop/start virtualization and Enable/Disable Cache 

.PARAMETER dcsserver
        [string] the server hostname as known in the DCS console.

.PARAMETER dcsuser
        [string] the admin user that can perform GET/PUT actions.

.PARAMETER dcspassword
        [string] the admin's password.

.PARAMETER dcsaction
        [string] Action to perform [ GetDcsStatus | DisableDcsCache | EnableDcsCache | StopDcsServer | StartDcsServer]


.EXAMPLE
        .\DcsUPSmanager.ps1 -dcsserver SDS621 -dcsuser Administrator -dcspassword Myp@ssw0rd -dcsaction GetDcsStatus
#>
param(
	[Parameter(mandatory=$false)]
    [string]$dcsserver,
	[Parameter(mandatory=$false)]
    [string]$dcsuser,
	[Parameter(mandatory=$false)]
    [string]$dcspassword,
	[Parameter(mandatory=$false)][ValidateSet("GetDcsStatus", "DisableDcsCache", "EnableDcsCache","StopDcsServer","StartDcsServer")]
    [string]$dcsaction,
    [Parameter(mandatory=$false)]
    [switch]$help
    )

function showhelp(){

if ( $help ) {
    help $MyInvocation.ScriptName -Detailed  }

}


function test-dcsaction() {

if ( $dcsaction -notin @("GetDcsStatus","DisableDcsCache","EnableDcsCache","StopDcsServer","StartDcsServer") ) {
        write-host "Action not set, please use either [GetDcsStatus | DisableDcsCache | Enable DcsCache | StopDcsServer | StartDcsServer]"
        exit 1
    }

}

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

      }
    catch
    {
        Write-Host $_ -ForegroundColor "Yellow"
    }

    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}


showhelp
test-dcsaction

Ignore-SelfSignedCerts


$headers = @{}
$headers.Add("ServerHost", $dcsserver)
$headers.Add("Authorization", "Basic $dcsuser $dcspassword")

$GLOBAL:SERVERS=$(
    try{ Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$dcsserver/RestService/rest.svc/1.0/servers}
    catch { 
        write-host "Unable to connect $dcsserver with user $dcsuser"
        Write-host "Encountered Error:"$_.Exception.Message
        exit 3
    }    
)

$DCSERVER=($SERVERS|?{$_.caption -eq $dcsserver})
if ( ! $DCSERVER) {
    write-host "-dcsserver parameter with match with known dcserver in the console [" ($SERVERS).caption "]"
    exit 3 
    }
$SERVERID=($DCSERVER).id

 Switch ($dcsaction)
 {
    GetDcsStatus {
        $DCSERVER
        }
    DisableDcsCache {
        $PARAMS = @{"CacheState"=1}
        Invoke-RestMethod -TimeoutSec 15 -Method PUT -Headers $headers -Uri https://$dcsserver/RestService/rest.svc/1.0/servers/$SERVERID -Body ($PARAMS|ConvertTo-Json)|select Caption,State,CacheState
        }
    EnableDcsCache {
        $PARAMS = @{"CacheState"=2}
        Invoke-RestMethod -TimeoutSec 15 -Method PUT -Headers $headers -Uri https://$dcsserver/RestService/rest.svc/1.0/servers/$SERVERID -Body ($PARAMS|ConvertTo-Json)|select Caption,State,CacheState
        }
    StopDcsServer {
        $PARAMS = @{"Operation"="StopServer"}
        Invoke-RestMethod -TimeoutSec 90 -Method POST -Headers $headers -Uri https://$dcsserver/RestService/rest.svc/1.0/servers/$SERVERID -Body ($PARAMS|ConvertTo-Json)|select Caption,State,CacheState
        }
    StartDcsServer {
        $PARAMS = @{"Operation"="StartServer"}
        Invoke-RestMethod -TimeoutSec 90 -Method POST -Headers $headers -Uri https://$dcsserver/RestService/rest.svc/1.0/servers/$SERVERID -Body ($PARAMS|ConvertTo-Json)|select Caption,State,CacheState
        }
 }