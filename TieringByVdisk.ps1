###################################################################################################################################
###################################################################################################################################
####
#### SANSYMPHONY - Tiering affinity by vdisk
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
$HEATMAP="$TMYinstallPath\HeatMapDumpCmd\DcsHeatmapDumpCmd.exe"

$TODAY=Get-Date -format "yyyyMMdd"
$OUT="$env:HOMEPATH\DESKTOP\$TODAY"
$FILES="$OUT\AutoTieringStatistics"




if (-not(get-module -Name PSWriteHTML) ) { Install-Module PSWriteHTML -Force }


if (-not(Test-Path -Path $OUT -PathType Container )) { New-Item -Path $OUT  -ItemType Directory }



$FILES=Get-ChildItem -Path "$InstallPath\AutoTieringStatistics" -Filter *.bak





connect-dcsserver -server $server 

Export-DcsObjectModel -OutputDirectory $OUT


# Fonctions
###############################################
function gather_data_from_xml {

    [XML]$DCSOBJECT=Get-Content((Get-ChildItem -Path $OUT -Recurse -Filter dcsobjectmodel.xml|select -First 1).fullname)

    $global:POOLS = $DCSOBJECT.DataRepository.DiskPoolData |select-object id,caption,maxtiernumber -ExpandProperty chunksize
    $global:POOLMEMBERS = $DCSOBJECT.DataRepository.PoolMemberData |select-object @{Name='ID';expression={'{' + $_.id + '}'}} , @{Name='Disk_Name';Expression={($_.Caption).replace(" ","_")}}
    $global:VDS= $DCSOBJECT.DataRepository.VirtualDiskData
    $global:VDISKS = $DCSOBJECT.DataRepository.StreamLogicalDiskData | Select-Object @{Name='vDiskId';expression={ ($_.mappingName).remove(0,2)}},@{Name='Vdisk';expression={$_.storagename}}
    $global:PROFILES=@($DCSOBJECT.DataRepository.StorageProfileData|select id,@{n="Profile";e={$_.caption}})
    
}




function dump_ast_files {

$i=0
$global:array = @(1,1,1,1,1,1)

           foreach ($POOL in $POOLS) {

                $POOLID=($POOL.id).remove(0,37)
                $POOLNAME=$POOL.caption -replace(" ","_")

                if ( $POOL.Value -gt 1GB) {
                        $global:SAUSIZE=$POOL.Value/1MB
                        $global:UNITE="MB"
                        }
                else {
                        $global:SAUSIZE=$POOL.Value/1GB
                        $global:UNITE="GB"
                    }

                
                write-host $POOLNAME
                (& $HEATMAP $FILES.fullname /H) -replace '\s+',';'|set-Content -path "$OUT\$POOLNAME.CSV"
                
                if (Test-Path "$OUT\$POOLNAME.CSV") { $global:array[$i] = Import-Csv -Delimiter ";" "$OUT\$POOLNAME.CSV" | sort tier,diskid,temp,vid
                $i++}
                }
}




# Scripts
#############################################



gather_data_from_xml
dump_ast_files
clear



$i=0
$table=@()
foreach ($POOL in $POOLS) {


                $POOLID=($POOL.id).remove(0,37)
                $POOLNAME=$POOL.caption -replace(" ","_")
                $MAXTIER=$POOL.MaxTierNumber

                if (!(Test-Path "$OUT\$POOLNAME.CSV")) {continue }
          
Write-Host "`nPOOL: $POOLNAME, MAXTIER: $MAXTIER, SAU SIZE: $SAUSIZE" -ForegroundColor Yellow


                #SAU Usage by vDisk
                $SAUbyVD=(
                    $array[$i] | Group-Object -Property vid,tier -NoElement| sort -Property Name | 
                    Select-Object -Property @{n='vdisk'; e={$_.name.split(',')[0]}},@{n='tier';e={($_.name.split(',')[1])}},count
                    )
    
    $match="!!!NA!!!"
    $COLOR="green"


             $SAUbyVD | Sort-Object -Property vdisk -Unique | %{
                            $TIER1=0
                            $TIER2=0
                            $TIER3=0
                            $TIER4=0
                            $TIER5=0

                            $match=$_.vdisk
                            $SAUbyVD | ? {$_.vdisk -eq $match} | % {
                        
                                $t0=[int]$_.tier
                                $c0=[int]$_.count
                                switch ($t0)
                                    {
                                        1 {[int]$TIER1=$c0*$SAUSIZE}
                                        2 {[int]$TIER2=$c0*$SAUSIZE}
                                        3 {[int]$TIER3=$c0*$SAUSIZE}
                                        4 {[int]$TIER4=$c0*$SAUSIZE}
                                        5 {[int]$TIER5=$c0*$SAUSIZE}
                                    }
                            }

                            
                            $ZEVDISK=($VDISKS | ? { $_.vdiskid -like $POOLID+"-"+$match.substring(2)}).vdisk
                            if (-not($ZEVDISK)){$ZEVDISK=$MATCH}
                            

                            
                             $object = New-Object -TypeName PSObject
                             $object | Add-Member -Name 'POOL' -MemberType Noteproperty -Value $POOLNAME
                             $object | Add-Member -Name 'VDISK' -MemberType Noteproperty -Value $ZeVDISK
                             $object | Add-Member -Name 'PROFILE' -MemberType Noteproperty -Value ($PROFILES|?{$_.ID -eq ($VDS|?{$_.caption -eq $ZEVDISK}|select StorageProfileId).StorageProfileId}).Profile
                             $object | Add-Member -Name 'T1' -MemberType Noteproperty -Value "$TIER1 $UNITE"
                             $object | Add-Member -Name 'T2' -MemberType Noteproperty -Value "$TIER2 $UNITE"
                             if ($maxtier -ge 3) {$object | Add-Member -Name 'T3' -MemberType Noteproperty -Value "$TIER3 $UNITE"}
                             if ($maxtier -ge 4) {$object | Add-Member -Name 'T4' -MemberType Noteproperty -Value "$TIER4 $UNITE"}
                             if ($maxtier -ge 5) {$object | Add-Member -Name 'T5' -MemberType Noteproperty -Value "$TIER5 $UNITE"}
                             $table += $object
                            
                            }


        

    



            $i++
            }

            $table|ft
            $table  |out-GridHtml -FilePath "$OUT\export.html" -DefaultSortColumn vdisk -PagingLength 50 