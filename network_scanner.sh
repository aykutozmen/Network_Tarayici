#!/bin/bash

# network_scanner.sh
Network=$1
Class=$2

Working_Directory="/etc/scanner/"
Argument_Count=$#

if [ "${Argument_Count}" -ne "2" ]
then
	echo "Arguman sayisi 2 olmali..."
	exit
fi

if [ "$Class" -ne "32" ] && [ "${Class}" -ne "24" ] && [ "${Class}" -ne "16" ] && [ "${Class}" -ne "8" ]
then
	echo "Class 8, 16, 24 veya 32 olmali..."
	exit
fi

Timestamp=`date +'%Y%m%d%H%M%S'`
# Files:
	Network_Listesi=${Working_Directory}"Network_Listesi_"${Network}"_"${Class}"_"${Timestamp}".csv"
	IP_Ping_Results=${Working_Directory}"IP_Ping_Results_"${Network}"_"${Class}"_"${Timestamp}".csv"
	IP_Pinglenebilir_Liste=${Working_Directory}"IP_Pinglenebilir_Liste_"${Network}"_"${Class}"_"${Timestamp}".csv"
	IP_Hostname_Pinglenebilir_Liste=${Working_Directory}"IP_Hostname_Pinglenebilir_Liste_"${Network}"_"${Class}"_"${Timestamp}".csv"
	SQL_Query_File_Full_Path=${Working_Directory}"SQL_Query_File.sql"
	SQL_Query_File="SQL_Query_File.sql"
	Dump_File="/tmp/dump"${Timestamp}".csv"
	Dump_File_Local=${Working_Directory}"dump"${Timestamp}".csv"
	: > $Network_Listesi
	
Cnt="${Network//[^.]}"
Dot_Count="${#Cnt}"
Octet_Count=$(( Dot_Count + 1 ))

Octet1=`echo $Network | awk -F'.' '{print $1}'`
Octet2=`echo $Network | awk -F'.' '{print $2}'`
Octet3=`echo $Network | awk -F'.' '{print $3}'`
Octet4=`echo $Network | awk -F'.' '{print $4}'`

case $Octet1 in
	''|*[!0-9]*) 	Octet1_Numeric="false" ;;
	*)				Octet1_Numeric="true"
esac

case $Octet2 in
	''|*[!0-9]*) 	Octet2_Numeric="false" ;;
	*)				Octet2_Numeric="true"
esac

case $Octet3 in
	''|*[!0-9]*) 	Octet3_Numeric="false" ;;
	*)				Octet3_Numeric="true"
esac

case $Octet4 in
	''|*[!0-9]*) 	Octet4_Numeric="false" ;;
	*)				Octet4_Numeric="true"
esac

case $Class in
	''|*[!0-9]*) 	Class_Numeric="false" ;;
	*)				Class_Numeric="true"
esac

if [ "$Octet_Count" -eq "4" ] && [ "$Octet1_Numeric" == "true" ] && [ "$Octet2_Numeric" == "true" ] && [ "$Octet3_Numeric" == "true" ] && [ "$Octet4_Numeric" == "true" ] && [ "$Class_Numeric" == "true" ] && [ "$Octet1" -gt "0" ] && [ "$Octet2" -ge "0" ] && [ "$Octet3" -ge "0" ] && [ "$Octet4" -ge "0" ] && [ "$Class" -gt "0" ] &&[ "$Octet1" -le "255" ] && [ "$Octet2" -le "255" ] && [ "$Octet3" -le "255" ] && [ "$Octet4" -le "255" ] && [ "$Class" -le "32" ]
then
	# "IP format, Class OK"
	# IP Listesini cikar:
	if [ "$Class" -eq "32" ]
	then
		IP=$Class
		# Ping kontrolu
		ping -c 1 $IP
		Result=`echo $?`
		if [ "$Result" -eq "0" ]
		then
			echo $IP";1" >> $IP_Ping_Results
		else
			echo $IP";0" >> $IP_Ping_Results
		fi
	elif [ "$Class" -eq "24" ]
	then
		sh ${Working_Directory}fpinger.sh ${Network} ${Class} ${IP_Hostname_Pinglenebilir_Liste} &
	elif [ "$Class" -eq "16" ]
	then
		# Octet3 ve Octet4 sayılarını göz ardı ederek tüm IP'leri listele:
		for (( o3=0; o3<255; o3++ ))
		do
			echo $Octet1"."$Octet2"."$o3".0" >> $Network_Listesi
		done
		Line_Count=`cat $Network_Listesi | grep -v '^$' | wc -l`
		for (( i=1; i<=$Line_Count; i++ ))
		do
			Network=`cat $Network_Listesi | grep -v '^$' | head -$i | tail -1`
			sh ${Working_Directory}fpinger.sh ${Network} 24 ${IP_Hostname_Pinglenebilir_Liste} &
			sleep 0.2
		done
	elif [ "$Class" -eq "8" ]
	then
		# Octet2, Octet3 ve Octet4 sayılarını göz ardı ederek tüm IP'leri listele:
		for (( o2=0; o2<255; o2++ ))
		do
			for (( o3=0; o3<255; o3++ ))
			do
				echo $Octet1"."$o2"."$o3".0" >> $Network_Listesi
			done
		done
		Line_Count=`cat $Network_Listesi | grep -v '^$' | wc -l`
		for (( i=1; i<=$Line_Count; i++ ))
		do
			Network=`cat $Network_Listesi | grep -v '^$' | head -$i | tail -1`
			sh ${Working_Directory}fpinger.sh ${Network} 24 ${IP_Hostname_Pinglenebilir_Liste} &
			sleep 0.2
		done
	fi
	while true
	do
		Pinger_Count=`ps -ef | grep -v grep | grep "${Working_Directory}fpinger.sh" | wc -l`
		if [ "$Pinger_Count" -eq "0" ]
		then
			break
		else
			sleep 2
		fi
	done
	rm -f ${Working_Directory}*.cln
	sed -i '/.254;255;None/d' $IP_Hostname_Pinglenebilir_Liste
	
	# Pinglenebilir IP'lerin envanterde kayıtlı ise kimin adına kayıtlı olduklarını bul
	echo "SELECT id, status_id, hostname, interface_1, interface_2, interface_3, interface_4, interface_5, interface_esx_mgmt, interface_ilo, administrator_department FROM envanter.assets WHERE status_id != 3 AND deleted_at IS NULL INTO OUTFILE ${Dump_File} FIELDS TERMINATED BY ';' LINES TERMINATED BY '\n';" > $SQL_Query_File_Full_Path
	sed -i "s/ INTO OUTFILE / INTO OUTFILE '/g" $SQL_Query_File_Full_Path
	sed -i "s/ FIELDS TERMINATED BY / FIELDS TERMINATED BY '/g" $SQL_Query_File_Full_Path
	
	sshpass -p 'SSHPASSW0RD!' scp $SQL_Query_File_Full_Path root@ENVANTER_SERVER_IP:/tmp/$SQL_Query_File
sshpass -p 'SSHPASSW0RD!' ssh root@ENVANTER_SERVER_IP << SSH_SESSION
mysql -u root -p'ENVANTER_DB_PASSW0RD1' < /tmp/$SQL_Query_File
SSH_SESSION
	sshpass -p 'SSHPASSW0RD!' scp root@ENVANTER_SERVER_IP:${Dump_File} ${Working_Directory}
sshpass -p 'SSHPASSW0RD!' ssh root@ENVANTER_SERVER_IP << SSH_SESSION
rm -f ${Dump_File} /tmp/${SQL_Query_File}
SSH_SESSION

	Line_Count=`cat ${IP_Hostname_Pinglenebilir_Liste} | grep -v '^$' | wc -l`
	for (( k=1; k<=${Line_Count}; k++ ))
	do
		cd ${Working_Directory}
		Line=`cat ${IP_Hostname_Pinglenebilir_Liste} | grep -v '^$' | head -$k | tail -1`
		IP=`echo $Line | awk -F';' '{print $1}'`
		Department=`grep -w "${IP};" ${Dump_File_Local} | head -1 | awk -F';' '{print $11}'`
		sed -i "s/${IP};/${IP};${Department};/g" $IP_Hostname_Pinglenebilir_Liste
	done
	rm -f ${SQL_Query_File_Full_Path} ${Dump_File_Local}
else
	echo "IP format, Class not OK!"
fi
