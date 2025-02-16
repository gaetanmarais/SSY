#!/bin/bash
#

if [ $(apt list net-tools|grep -c installed) = 0 ]; then apt install net-tools -y &>/dev/null ; fi
ISCSIPATH="/etc/iscsi/send_targets"
LIST=$(find $ISCSIPATH -type f)

for FILE in $LIST
do
  PORTAL=$(awk -F"=" '/discovery.sendtargets.address/ {print $2}' $FILE)

  #Check if server is already connected
  if [ $(netstat -an | grep $PORTAL:3260 | grep -c ESTABLISHED) != 1 ]; then
      NMAP=$(nmap -p 3260 $PORTAL)
      if [ $(echo $NMAP|grep -c "3260/tcp open") = 0 ]; then
        echo "Service iSCSI (3260/tcp) is not started on $PORTAL"|systemd-cat -t $0
      else
        echo "Portal $PORTAL is listening but node is not connected"|systemd-cat -t $0
        RESCAN=1
        iscsiadm -m discovery -t sendtargets -p $PORTAL --login|systemd-cat -t $0
      fi
  else
    echo "node is connected to $PORTAL, everything is OK"
  fi
done

if [ "$RESCAN" == "1" ] ; then iscsiadm -m session --rescan|systemd-cat -t $0; fi
