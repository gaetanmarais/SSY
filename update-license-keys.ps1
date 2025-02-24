$FILE="C:\users\gmarais\OneDrive - DataCore Software Corporation\Desktop\Scripts\SSY\list.txt"


$Licenses = @("M72H6-30JBS","PG03H-1S6JG")
$COMPANY = "DataCore"
$CONTACT = "Gaetan MARAIS"
$EMAIL = "gaetan.marais@datacore.com"
$PHONE = "+33662807575"


$J=1

try {
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
catch {Write-Host $_ -ForegroundColor "Yellow"}

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    
$OUTFILE=@()
$LINES=Get-Content -Path $FILE

$LINES|%{

    $LINE=$_
    if ( $LINE -like "#*" -or [string]::IsNullOrEmpty($_) ) {return}
    
    $dcsserver=($LINE -split(";"))[0]
    $dcsuser=($LINE -split(";"))[1]
    $dcspwd=($LINE -split(";"))[2]


    $headers = @{}
    $headers.Add("ServerHost", $dcsserver)
    $headers.Add("Authorization", "Basic $dcsuser $dcspwd")
    $ERR=0


    try { $GLOBAL:SERVERS=$(Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$dcsserver/RestService/rest.svc/1.0/servers) }
    catch {
        $LICERROR=$_
        $ERR=1
        Write-Host "Error Gathering server : $dcsserver" -BackgroundColor Red
        $RESULT=New-Object PSObject
        $RESULT|Add-Member -MemberType NoteProperty -Name "#" -Value $J
        $RESULT|Add-Member -MemberType NoteProperty -Name "SERVER" -Value $DCSSERVER
        $RESULT|Add-Member -MemberType NoteProperty -Name "SRVGRP" -Value "-"
        $RESULT|Add-Member -MemberType NoteProperty -Name "RESULT" -Value $LICERROR
        $OUTFILE+=$RESULT
        $J++
        return
    }


    try { $GLOBAL:GROUPS=$(Invoke-RestMethod -TimeoutSec 15 -Method GET -Headers $headers -Uri https://$dcsserver/RestService/rest.svc/1.0/ServerGroups) }
    catch {
        $LICERROR=$_
        $ERR=1
        Write-Host "Error Gathering server : $dcsserver" -BackgroundColor Red
        $RESULT=New-Object PSObject
        $RESULT|Add-Member -MemberType NoteProperty -Name "#" -Value $J
        $RESULT|Add-Member -MemberType NoteProperty -Name "SERVER" -Value $DCSSERVER
        $RESULT|Add-Member -MemberType NoteProperty -Name "SRVGRP" -Value "-"
        $RESULT|Add-Member -MemberType NoteProperty -Name "RESULT" -Value $LICERROR
        $OUTFILE+=$RESULT
        $J++
        return
    }
    
    $i=0

    $SERVERS| % {
        $SERVER_=$_
        $PARAMS = @{
            "Server" = $SERVER_.id;
            "ServerKey" = $LICENSES[$i];
            "CompanyName" = $COMPANY;
            "ContactName" = $CONTACT;
            "EmailAddress" = $EMAIL;
            "PhoneNumber" = $PHONE
            }

        try {
            Invoke-RestMethod -TimeoutSec 15 -Method POST -Headers $headers -Uri https://${dcsserver}/RestService/rest.svc/1.0/licenses -Body (${PARAMS}|ConvertTo-Json) -ErrorAction Stop  
            $RESULT=New-Object PSObject
            $RESULT|Add-Member -MemberType NoteProperty -Name "#" -Value $J
            $RESULT|Add-Member -MemberType NoteProperty -Name "SERVER" -Value $SERVER_.caption
            $RESULT|Add-Member -MemberType NoteProperty -Name "SRVGRP" -Value $GROUPS.ID
            $RESULT|Add-Member -MemberType NoteProperty -Name "RESULT" -Value $LICENSES[$i]
            }
        catch {
            $LICERROR=$_
            Write-Host $LICERROR -BackgroundColor Red 
            $RESULT=New-Object PSObject
            $RESULT|Add-Member -MemberType NoteProperty -Name "#" -Value $J
            $RESULT|Add-Member -MemberType NoteProperty -Name "SERVER" -Value $SERVER_.caption
            $RESULT|Add-Member -MemberType NoteProperty -Name "SRVGRP" -Value $GROUPS.ID
            $RESULT|Add-Member -MemberType NoteProperty -Name "RESULT" -Value $LICERROR
            }
        $i++
        $OUTFILE+=$RESULT
        }
    $J++
}


$OUTFILE
$OutFILE|ConvertTo-Csv -Delimiter ";" -NoTypeInformation|Out-File -FilePath $FILE".csv"
