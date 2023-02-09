#!/bin/sh

#
# Check Network and HBA Firwmare and Drivers HCL
#
# Author  : Gaetan MARAIS
# Version : 1.0
#
#######################################################


clear
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
echo "https://www.vmware.com/resources/compatibility/search.php?deviceCategory=io&details=1&VID=$VID&DID=$DID&SVID=$SVID&SSID=$SSID&page=1&display_interval=10&sortColumn=Partner&sortOrder=Asc"
echo "-------------------------------------------------"
done


#HBA
echo "HBA"
echo "-------------------------------------------------"

#SAS list
esxcli storage san sas list

SAS=$(esxcli storage san sas list | grep "Device Name")
for NAME in `echo $SAS| awk -F":" '{print $2}'`
do
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
