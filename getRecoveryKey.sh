#!/bin/bash
# Michael Rieder 10.10.2022
# Request personal recovery key from the commandline (Jamf Pro On-Prem only)
# Usage getRecoveryKey.sh computername|jamf-computerid

# set to TRUE for debug
DEBUG="FALSE"

## in case of jamf cluster i recommend to point direct to a cluster member instead of the loadbalancer
URL="https://jamf.mycompany.net:8443"
USER="jamfpro-user"
PASS="xxxxxxxxxxx"


## obtain a JESSIONID for authentication
SESSIONID=$(curl -k $URL'/index.html' \
  			--header 'Content-Type: application/x-www-form-urlencoded' \
  			--data-urlencode "username=$USER" \
  			--data-urlencode "password=$PASS" \
  			-H 'Connection: keep-alive' \
  			-s  -c -)

JSESSIONID=$(echo $SESSIONID | grep JSESSIONID | awk {'print $NF'} )
[ $DEBUG == "TRUE" ] && echo "JSESSIONID=${JSESSIONID}"



#### If parameter 1 is only numeric we expect a computerid otherwise we search for the id on jamf side.
if [[ $1 =~ ^[0-9]+$ ]]
then
    COMPUTERID=$1
    [ $DEBUG == "TRUE" ] && echo "COMPUTERID=${COMPUTERID}"
else
 	SEARCHCOMPUTER=$(curl -sk $URL'/legacy/computers.html?query='${1}'&queryType=COMPUTERS' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H 'Connection: keep-alive' \
    -H 'Cookie: JSESSIONID='${JSESSIONID} )
  	COMPUTERID=$(echo $SEARCHCOMPUTER |sed 's/.*<a class="view devices-table-row-view arrowBg" href="computers.html?id=\([a-zA-Z0-9]*\)&o=r">.*/\1/p' | tail -1)
  
 [ $DEBUG == "TRUE" ] && echo "COMPUTERID JAMF=${COMPUTERID}"
fi


HTMLCONTENT=$(curl -k -s $URL'/legacy/computers.html?id='$COMPUTERID'&o=r' \
	  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
	  -H 'Cookie: JSESSIONID='${JSESSIONID} \
	  -H 'Connection: keep-alive' \
	  -H 'Referer: '$URL'/computers.html?id='$COMPUTERID'&o=r' )

SESSION_TOKEN=$(echo $HTMLCONTENT |sed 's/.*<input type="hidden" name="session-token" id="session-token" value="\([a-zA-Z0-9]*\)">.*/\1/p')
KEYID=$(echo $HTMLCONTENT |sed -n 's/.*retrieveFV2Key&#x28;\([0-9]*\),&#x20;&#x27.*/\1/p' )



[ $DEBUG == "TRUE" ] && echo "KEYID=${KEYID}"


KEY=$(curl -k -s $URL'/computers.ajax?id='$COMPUTERID'&o=r' \
  -H 'Cookie: JSESSIONID='${JSESSIONID} \
  -H 'Connection: keep-alive' \
  --data-raw 'fileVaultKeyId='${KEYID}'&fileVaultKeyType=individualKey&identifier=FIELD_FILEVAULT2_INDIVIDUAL_KEY&ajaxAction=AJAX_ACTION_READ_FILE_VAULT_2_KEY&session-token='${SESSION_TOKEN} )

KEY=$(echo $KEY |sed 's:.*<individualKey>\(.*\)</individualKey>.*:\1:p' )

echo $KEY | awk -F " " {'print $NF'}



