#!/bin/sh

#
# Check Network and HBA Firwmare and Drivers HCL
#
# Author  : Gaetan MARAIS
# Version : 2.0   25/03/18  - update for broadcom links
#
#######################################################


clear


#Show ESX version
echo "ESX VERSION"
echo "-------------------------------------------------"
esxcli system version get
echo "-------------------------------------------------"


#Check NETWORK
echo "NETWORK"
echo "-------------------------------------------------"
for NAME in `vmkchdev -l | grep vmnic | awk '{print$5}'`
do echo $NAME
esxcli network nic get -n $NAME|grep "Driver Info" -A 4
echo "VID :DID  SVID:SDID"
VALUE=$(vmkchdev -l | grep $NAME | awk '{print $2, $3}')
VID=$(echo $VALUE|awk '{print $1}'|awk -F":" '{print $1}')
DID=$(echo $VALUE|awk '{print $1}'|awk -F":" '{print $2}')
SVID=$(echo $VALUE|awk '{print $2}'|awk -F":" '{print $1}')
SSID=$(echo $VALUE|awk '{print $2}'|awk -F":" '{print $2}')
echo "$VID:$DID $SVID:$SSID"
#echo "https://www.vmware.com/resources/compatibility/search.php?deviceCategory=io&details=1&VID=$VID&DID=$DID&SVID=$SVID&SSID=$SSID&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc"
echo "https://compatibilityguide.broadcom.com/search?program=io&persona=live&column=brandName&order=asc&vid=$VID&did=$DID&svid=$SVID&maxSsid=$SSID&activePage=1&activeDelta=20"

echo "-------------------------------------------------"
done


#HBA
echo "HBA"
echo "-------------------------------------------------"


SAS=$(esxcli storage san sas list | grep "Device Name")
for NAME in `echo "$SAS"| awk -F":" '{print $2}'`
do
esxcli storage san sas list -A $NAME
echo "VID :DID  SVID:SDID"
VALUE=$(vmkchdev -l | grep $NAME | awk '{print $2, $3}')
VID=$(echo $VALUE|awk '{print $1}'|awk -F":" '{print $1}')
DID=$(echo $VALUE|awk '{print $1}'|awk -F":" '{print $2}')
SVID=$(echo $VALUE|awk '{print $2}'|awk -F":" '{print $1}')
SSID=$(echo $VALUE|awk '{print $2}'|awk -F":" '{print $2}')
echo "$VID:$DID $SVID:$SSID"
echo "https://www.vmware.com/resources/compatibility/search.php?deviceCategory=io&details=1&VID=$VID&DID=$DID&SVID=$SVID&SSID=$SSID&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc"
echo "-------------------------------------------------"
done

#HBA
echo "FC"
echo "-------------------------------------------------"


FIBERC=$(esxcli storage san fc list | grep "Device Name")
for NAME in `echo "$FIBERC"| awk -F":" '{print $2}'`
do
esxcli storage san fc list -A $NAME
echo "VID :DID  SVID:SDID"
VALUE=$(vmkchdev -l | grep $NAME | awk '{print $2, $3}')
VID=$(echo $VALUE|awk '{print $1}'|awk -F":" '{print $1}')
DID=$(echo $VALUE|awk '{print $1}'|awk -F":" '{print $2}')
SVID=$(echo $VALUE|awk '{print $2}'|awk -F":" '{print $1}')
SSID=$(echo $VALUE|awk '{print $2}'|awk -F":" '{print $2}')
echo "$VID:$DID $SVID:$SSID"
echo "https://www.vmware.com/resources/compatibility/search.php?deviceCategory=io&details=1&VID=$VID&DID=$DID&SVID=$SVID&SSID=$SSID&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc"
echo "-------------------------------------------------"

done
