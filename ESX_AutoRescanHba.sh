#!/bin/sh ++group=host/vim/vmvisor/boot



SDS="SDS621"


#check status of DataCore SDS VirtualMachine
# get VMID
VMID=$(vim-cmd vmsvc/getallvms |grep -i ${SDS})


#Start SDS VM is not already started 
if [ $(vim-cmd vmsvc/power.getstate $VMID|grep -c "Powered on") -eq 0 ]
    then vim-cmd vmsvc/power.on $VMID
fi 
echo "${SDS} VM is started"


#Wait for VM started and VM guest agent is green
while [ $(vim-cmd vmsvc/get.guestheartbeatStatus $VMID) != "green" ]
do
        sleep 30
done
echo "${SDS} VM guest agent is green"
        
#wait for DataCore service start (~1minute)
echo "wait for 1 minute..."
sleep 60
        
#Rescan iSCSI HBA while all target are failed
check=$(esxcli iscsi adapter target list|grep -c "Error=")
while [ $check -ne 0 ]
do
	esxcfg-swiscsi -s
	echo "Rescan iSCSI HBA..."
        sleep 30
        check=$(esxcli iscsi adapter target list|grep -c "Error=")
	if [ ${check} -ne 0 ]; then echo "Still some errors on iSCSI targets list (${check})"; fi
done
echo "No errors on iSCSI targets, :)"


