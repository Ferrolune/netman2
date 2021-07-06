#!/bin/bash
cd "$(dirname ${BASH_SOURCE[0]})"
pushd map > /dev/null
OPTIONS=()
popd > /dev/null
SERVER=$(cat /etc/hostname)
CHOICE_HEIGHT=20
BACKTITLE="System Control Panel for $SERVER"
TITLE="Options"
MENU="Choose one of the following options: " 
IFS=','


#since ports are limited to devices that are supported by the script, the script must be updated manually.
#for instance, ssh is generally port 22 and is supported, wheras ftp is 20/21 and is not supported and wont be scanned.
#Can be set to "-F" or "0-65535" or specifics, do note that more ports slows the scan down significantly but will find otherwise hidden devices.
#scanning 0-65535 will take 8192 times longer than just scanning 8 ports so try to limit the PORTS variable as much as possible
PORTS="21,22,80,42069"
#PORTS="-F"
#PORTS="0-65535"


#subnet algorithm
if [ "$3" = "4" ]; then

HEIGHT=40
WIDTH=60
	declare -a adr;
	let "i=0"

adr=$(ip route | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | uniq |tr '\n' ',')
adr=($adr)
	let "j=1"
	OPTIONS+=(b "Back")
	for i in "${adr[@]}"
	do
		OPTIONS+=($j "$i")
		let "j=j+1"

	done

	while [ $$ -ne $2 ]
	do

		CHOICE=$(whiptail --clear \
		--backtitle "$BACKTITLE" \
		--title "$TITLE" \
		--nocancel \
		--menu "Select a Subnet to browse" $HEIGHT $WIDTH $CHOICE_HEIGHT \
		"${OPTIONS[@]}" \
		2>&1 > /dev/tty)


		clear
		case $CHOICE in
			*)
	   		    clear
				if [ $CHOICE == "b" ]; then
					break;
				fi

				./sshlogin.sh "${adr[$(($CHOICE-1))]}" $$ "2"
			    ;;
		esac
	done


fi


#algorithm to manage this device. Config file exists for this.
if [ "$3" = "1" ]; then
HEIGHT=40
WIDTH=60

declare -A matrix
declare -i Row=0
declare -i Col=1

	while read -ra ARR;
	do
		for i in "${ARR[@]}"
		do
			matrix[$Col,$Row]=$i;
			((Row=Row+1))
		done
		((Row=0))
		((Col=Col+1))
	done < $1

	Col2=1
	while [ $((Col)) -ne $((Col2)) ]
	do
		OPTIONS+=($Col2 "${matrix[$Col2,0]}")
		let "Col2+=1"
	done
	while [ $$ -ne $2 ]
	do

	CHOICE=$(whiptail --clear \
	--backtitle "$BACKTITLE" \
	--title "$TITLE" \
	--nocancel \
	--menu "Choose an option" $HEIGHT $WIDTH $CHOICE_HEIGHT \
	"${OPTIONS[@]}" \
	2>&1 > /dev/tty)


		clear
		case $CHOICE in
			*)
	   		    clear
			    eval "${matrix[$CHOICE,1]}"
			    ;;
		esac
	done
fi


#algorithm to search for other devices on the given subnet from $3=4
if [ "$3" = "2"  ]; then
	
	HEIGHT=40
	WIDTH=60
	#first, get network base ip, this won't work with ipv4
	echo "Constructing table for net $BASEIPADDRESS..."
	BASEIPADDRESS=$1
	#then map the open ips across the net, this is the list items to be saved to conf for mode 2 to show which devices have
	
	echo $BASEIPADDRESS
 	declare -a IPADDRESSES
	IPADDRESSES=$(nmap -Pn -n -p"$PORTS" --min-parallelism 100 --max-retries 0 -T5 $BASEIPADDRESS.0-255 -oG - | grep "/open" | awk '{ print $2 }' | tr '\n' ',')
	

	#this command will grab all ips on the subnet that uses the 100 most common ports





	echo $IPADDRESSES
	declare -a IPARRAY=($IPADDRESSES)
	#TODO: finish conf output logic below
	names=$(nmap $IPADDRESSES -Pn -p"$PORTS" --min-parallelism 100 --max-retries 0 -T5 -oG - | grep 'Ports' | awk '{print $3 $2}' | tr '\n' ',')
	echo ""
	names=($names)
	let "k=0"
	OPTIONS+=(b "Back")

	for i in "${names[@]}"
	do

		name=$(echo "${names[$k]}" | cut -d ")" -f 1 | cut -d "(" -f 2)
		ip=$(echo "${names[$k]}" | cut -d ")" -f 2)

		echo "$ip"/"$name"

			if [ "$name" = "$ip" ]; then
				echo "Found non-reliable host"
				OPTIONS+=($(($k+1)) "$ip")
			else
				OPTIONS+=($(($k+1)) "$name/$ip")
			fi
			let "k+=1"
	done


	while [ $$ -ne $2 ]
	do
	CHOICE=$(whiptail --clear \
	--backtitle "$BACKTITLE" \
	--title "$TITLE" \
	--nocancel \
	--menu "Choose an option" $HEIGHT $WIDTH $CHOICE_HEIGHT \
	"${OPTIONS[@]}" \
	2>&1 > /dev/tty)

		
		case $CHOICE in
			*)
	   		    clear
			    	if [ $CHOICE == "b" ]; then
					break;
				fi

			    let "j=$CHOICE-1"
			    ./sshlogin.sh "this" $$ "3" ${IPARRAY[j]}
			    ;;
		esac
	done
fi
FTPWASREAD="0"
HTTPWASREAD="0"
#algorithm to search for open ports on a device from $3=2
if [ "$3" = "3" ]; then
HEIGHT=40
WIDTH=60
	#then we'll get a list of open ports, separated by a ^$ for each ip address that was passed
	OPENPORTS=$(nmap $4 -Pn -n -p"$PORTS" --min-parallelism 100 --max-retries -T5 | awk '{print $1}' | grep  '/\|^$' | cut -d "/" -f 1 | tr '\n' ',')

	declare -a OPARR=($OPENPORTS)
	let "n=1"
	printf "Select User On Device: "
	read SSHUSER
	OPTIONS+=(b "Back")
	for i in "${OPARR[@]}"
	do
		if [ $? -ne $((0)) ]; then
			kill $$
		fi

		case $i in
		"20" | "21")
			if [ $(($FTPWASREAD)) -eq $(("0")) ]; then
				OPTIONS+=($n "lftp $SSHUSER@$4")
				let "n+=1"
				FTPWASREAD="1"
			fi
			;;

		"22")
			echo " "
			printf "SSH hidden port: "
			read sshport
			OPTIONS+=($n "ssh $SSHUSER@$4 -p $sshport")
			let "n+=1"
			;;
		"80" | "443")
			if [ $(($HTTPWASREAD)) -eq $(("0")) ]; then
				OPTIONS+=($n "elinks $4")
				let "n+=1"
				HTTPWASREAD="1"

			fi
			;;
		esac

	done
	let "n+=1"

	while [ $$ -ne $2 ]
	do
		CHOICE=$(whiptail --clear \
		--backtitle "$BACKTITLE" \
		--title "$TITLE" \
		--nocancel \
		--menu "Choose an option" $HEIGHT $WIDTH $CHOICE_HEIGHT \
		"${OPTIONS[@]}" \
		2>&1 >/dev/tty)

		clear
		case $CHOICE in
			*)

			    	if [ $CHOICE == "b" ]; then
					break;
				fi
				
				let "n=$CHOICE+$CHOICE+1"
				eval "${OPTIONS[$n]}"
				;;
		esac
	done

fi
