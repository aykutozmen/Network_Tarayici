#!/bin/bash
# fpinger.sh

Network=$1
Class=$2
IP_Hostname_Pinglenebilir_Liste=$3
Working_Directory="/etc/scanner/"
File_Name=${Working_Directory}".fpinger_output_"$Network"_"$Class".out"
File_Name_Clean=${Working_Directory}".fpinger_output_"$Network"_"$Class".cln"

/usr/sbin/fping -q -a -s -g ${Network}/${Class} > $File_Name 2>&1

grep -v 'elapsed real time' $File_Name | grep -v '^$' | grep -v targets | grep -v alive | grep -v unreachable | grep -v 'unknown addresses' | grep -v 'timeouts' | grep -v 'ICMP echos sent' | grep -v 'ICMP Echo Replies received' | grep -v 'other ICMP received' | grep -v 'round trip time' | grep -v 'ICMP Time Exceeded' > $File_Name_Clean
rm -f $File_Name

Count=`wc -l $File_Name_Clean | awk '{print $1}'`
for (( i=1; i<=$Count; i++ ))
do
	IP=`grep -v '^$' $File_Name_Clean | head -$i | tail -1`
	DNS_Record_Result=`host ${IP} | grep 'domain name pointer ' | wc -l`
	
	if [ "${DNS_Record_Result}" -eq "1" ]
	then
		Hostname=`host ${IP} | awk -F'domain name pointer ' '{print $2}' | sed 's/net./net/g' | sed 's/NET./NET/g'
	elif [ "${DNS_Record_Result}" -gt "1" ]
	then
		Hostname=`host ${IP} | awk -F'domain name pointer ' '{print $2}' | sed 's/.\{1\}$//' | sed -z 's/\n/,/g;s/,$/\n/'`
	else
		Hostname="None"
	fi
	
	TTL=`ping -c 1 $IP | grep 'icmp seq' | awk -F'ttl=' '{print $2}' | awk -F'time=' '{print $1}'`
	if [[ "$TTL" -le "64" ]] ; then TTL="Linux"; elif [[ "$TTL" -lt "128" ]] && [[ "$TTL" -gt "64" ]] ; then TTL="Windows" ; fi
	echo $IP";"$TTL";"$Hostname >> $IP_Hostname_Pinglenebilir_Liste
	
done
