#!/bin/bash

SCRIPT_DIR=`pwd`

# About: script for downloading power data on CloudLab

URL_U=http://emmy10.casa.umass.edu:8080/CloudLabWebPortal/UtahExportInOne
URL_C=http://emmy10.casa.umass.edu:8080/CloudLabWebPortal/ClemsonExportInOne
URL_W=http://emmy10.casa.umass.edu:8080/CloudLabWebPortal/WiscExportInOne

GETOPT_CMD=getopt
# Specific to OSX; the path is machine-specific
if [[ $OSTYPE == "darwin"* ]] ; then
  GETOPT_CMD=/usr/local/Cellar/gnu-getopt/1.1.6/bin/getopt
else
  apt-get update
  apt-get install -y unzip curl
fi

# If set, try getting power data for all three sites
INCLUDE_ALL=0
# If set, try getting power data for the specified site
ENTIRE_SITE=0

# Read parameters
TEMP=`"$GETOPT_CMD" -o s:l:ae --long site:,last:,all,entire-site -n 'power-client.sh' -- "$@"`
eval set -- "$TEMP"

# Extract and process command line arguments
while true ; do
    case "$1" in
        -s|--site)
            case "$2" in
                "") shift 2 ;;
                *) SITE=$2 ; shift 2 ;;
            esac ;;
        -l|--last)
            case "$2" in
                *) LAST=$2 ; shift 2 ;;
            esac ;;
        -a|--all)  INCLUDE_ALL=1 ; shift ;;
        -e|--entire-site)  ENTIRE_SITE=1 ; shift ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

case "$SITE" in
  utah|UTAH)
    URL=$URL_U ;;
  clemson|CLEMSON)
    URL=$URL_C ;;
  wisconsin|WISCONSIN)
    URL=$URL_W ;;
esac

if [ $INCLUDE_ALL -eq 0 ] ; then
  if [ -z "$URL" ] ; then
    echo "URL is unset. -s or --site is not set correctly (-a or --all is not used)."
    exit 1
  fi
fi 

# If the number of days is provided
if [[ $LAST == *d ]] ; then
  # Strip last d
  d=${LAST%*d*}
  HOURS=$((d*24))
fi
# If the number of hours is provided
if [[ $LAST == *h ]] ; then
  # Strip last h
  h=${LAST%*h*}
  HOURS=$((h*1))
fi
if [ -z "$HOURS" ] ; then
  echo "HOURS is unset. -l or --last is not used correctly -- the argument should be in the format: Xd (for X days) or Yh (for Y hours)"
  exit 1
fi

# Setting Start and End timestamps
END=`date -u '+%Y-%m-%d %H:%M'`
NOW=`date -u +%s`
START_S=$(($NOW-$HOURS*3600))
START=`date -u -r "$START_S" '+%Y-%m-%d %H:%M'`
echo "START=$START"
echo "END=$END"

cd /tmp
if [ $INCLUDE_ALL -eq 1 ] ; then
  curl -o power_u.zip -F "start=$START" -F "end=$END" $URL_U
  curl -o power_c.zip -F "start=$START" -F "end=$END" $URL_C
  curl -o power_w.zip -F "start=$START" -F "end=$END" $URL_W
  LIST="power_u.zip power_c.zip power_w.zip"
elif [ $ENTIRE_SITE -eq 1 ] ; then 
  curl -o power.zip -F "start=$START" -F "end=$END" $URL
  LIST="power.zip"
else
  # Obtain the manifest
  MAN=manifest.xml
  curl -o power.zip -F "start=$START" -F "end=$END" -F "cloudlab-manifest=@$MAN" $URL
  LIST="power.zip"
fi

FINAL_DEST=$SCRIPT_DIR/power
mkdir -p $FINAL_DEST

# Preserve *.csv in $FINAL_DEST but move them elsewhere
mkdir -p "$FINAL_DEST-BACKUP"
mv $FINAL_DEST/*.csv "$FINAL_DEST-BACKUP" 2>/dev/null

# Temporary location
PTMP=/tmp/power-raw

for el in $LIST; do

  # Don't reuse old data in the temporary location
  rm -rf $PTMP
  mkdir -p $PTMP
  
  unzip $el -d $PTMP > /dev/null
  
  # Trying to use hostnames instead of resource IDs
  cat $PTMP/resource.csv | egrep "^[0-9]+,*" | grep -v "Power Supply" | grep -v "chassis" | while IFS= read -r line
  do
    resource_id=`echo $line | cut -d, -f1`
    client_id=`echo $line | cut -d, -f6`
    #echo $client_id
    if [ "$client_id" == "null" ]; then
      #host=$client_id
      continue
    else 
      # Recognize client_IDs that belong to different sites and construct full hostnames
      if [[ $client_id == pc* ]] ; then 
        host="$client_id".wisc.cloudlab.us 
      elif [[ $client_id == cl* ]] ; then 
        host_tmp=`echo $client_id | sed 's/-man0//'`
        host="$host_tmp".clemson.cloudlab.us
      elif [[ $client_id == c* ]] ; then 
        chassis_id=`echo $line | cut -d, -f5`
        cartridge_id=`echo $client_id | sed 's/n.*//' | sed 's/c//'`
        host=ms0"$chassis_id$cartridge_id".utah.cloudlab.us
      fi
      #echo "$resource_id ---- $host"
      cp "$PTMP/$resource_id.csv" "$FINAL_DEST/$host.csv"
    fi 
  done

done

# List obtained files and show how many samples they have
wc -l $FINAL_DEST/*
