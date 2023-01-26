#!/bin/bash
#
#
# Author      : Gaetan MARAIS
# Version     : 1.0
# Date        : 26/01/2023
# Description : Check path policy for DataCore Virtual disks devices and change it to RoundRobin if needed
#
#
##########################################################


#list all DataCore Virtual disks devices (naa.60030d9)

esxcli storage core adapter device list | awk '/naa.60030d9/ {print $2}'| while read NAA
do

        #dump some data
        DEVICE=$(esxcli storage nmp device list --device $NAA)
        NAME=$(echo "$DEVICE"| awk -F":" '/Device Display Name:/ {print $2}')
        PSP=$(echo "$DEVICE"| awk -F":" '/Path Selection Policy:/ {print $2}')
        OPTION=$(echo "$DEVICE"| awk -F":" '/Path Selection Policy Device Config:/ {print $2}')
        let NC=58-$(echo $NAME|wc -L)
        BLANK=$(awk -v nc=$NC 'BEGIN{for(c=0;c<nc;c++) printf " "}')

        NEWPSP=""
        #check if the PSP is VMware RoundRobin PSP
        if [[ "$PSP" != " VMW_PSP_RR" ]]
        then

                #If it's not PSP RR, it will change it to RoundRobin policy
                esxcli storage nmp device set --device $NAA --psp VMW_PSP_RR
                echo "$NAA ($NAME)$BLANK $PSP $OPTION changed to VMW_PSP_RR"
        else
                echo "$NAA ($NAME)$BLANK $PSP $OPTION"
        fi
done
