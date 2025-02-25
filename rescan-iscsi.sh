#!/bin/bash
#


if [ $(whereis -b netstat | wc -w) -eq 1 ] ; then
  echo "netstat package is missing, script is aborted"
  echo "  try to install it with apt install net-tools"
  exit 10
fi


if [ "$1" == "-cronit" ] && [ $(grep -c $0 /etc/crontab) -eq 0 ]; then
  cp $0 /etc/cron.d
  echo "* * * * * root /etc/cron.d/$0 >/dev/null 2>&1">>/etc/crontab
  /etc/init.d/cron reload
fi



if [ $(grep -c $0 /etc/crontab) -eq 0 ]; then
  printf "\n\nScript is not in crontab !!! :(\n"
  printf "To add it into crontab, execute $0 -cronit\n"
fi



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
  fi
done

if [ "$RESCAN" == "1" ] ; then iscsiadm -m session --rescan|systemd-cat -t $0; fi
