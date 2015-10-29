#!/bin/bash

# About:

dpkg -l | grep unzip
if [ $? -ne 0 ]; then
  apt-get update
  apt-get install -y unzip
fi

# Read parameters
TEMP=`getopt -o s:l: --long site:last: -n 'UMass-obtain-power.sh' -- "$@"`
eval set -- "$TEMP"

# Extract options and their arguments into variables
while true ; do
    case "$1" in
        -s|--site)
            case "$2" in
                "") shift 2 ;;
                *) SITE=$2 ; shift 2 ;;
            esac ;;
        -l|--last)
            case "$2" in
                "") shift 2 ;;
                *) LAST=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

case "$SITE" in
  utah|UTAH)
    URL=http://emmy10.casa.umass.edu:8080/CloudLabWebPortal/UtahExportInOne ;;
  clemson|CLEMSON)
    URL=http://emmy10.casa.umass.edu:8080/CloudLabWebPortal/ClemsonExportInOne ;;
  wisconsin|WISCONSIN)
    URL=http://emmy10.casa.umass.edu:8080/CloudLabWebPortal/WiscExportInOne ;;
esac

if [ -z "$URL" ] ; then
  echo "URL is unset. --s or --site is not set correctly"
  exit 1
fi
#echo "URL=$URL"

if [[ $LAST == *d ]] ; then
  # Strip last d
  d=${LAST%*d*}
  HOURS=$((d*24))
fi
if [[ $LAST == *h ]] ; then
  # Strip last h
  h=${LAST%*h*}
  HOURS=$((h*1))
fi
if [ -z "$HOURS" ] ; then
  echo "HOURS is unset. -l or --last is not set correctly -- should be in the format Xd (for X days) or Yh (for Y hours)"
  exit 1
fi
echo "HOURS=$HOURS"

PTMP=/tmp/umass-power-raw
MAN=/tmp/manifest.xml

END=`date -u +%Y-%m-%d\ %H:%M`
NOW=`date -u +%s`
START_S=$(($NOW-$HOURS*3600))
START=`date -u -d@"$START_S" +%Y-%m-%d\ %H:%M`
echo "START=$START"
echo "END=$END"

cd /tmp
geni-get manifest > $MAN
curl -o power.zip -F "start=$START" -F "end=$END" -F "cloudlab-manifest=@$MAN" $URL
rm -rf $PTMP
mkdir $PTMP
unzip power.zip -d $PTMP > /dev/null
#wc -l $PTMP/*

FINAL_DEST=/var/log/power
mkdir $FINAL_DEST
# Preserve *.csv in $FINAL_DEST but move them elsewhere
mkdir "$FINAL_DEST-BACKUP"
mv $FINAL_DEST/*.csv "$FINAL_DEST-BACKUP"

# Trying to use hostnames instead of resource IDs
cat $PTMP/resource.csv | grep urn:publicid:IDN
if [ $? -ne 0 ]; then
  # No component_IDs reported, copy "as is"
  rsync -av $PTMP/ $FINAL_DEST/ --exclude=resource.csv --exclude=webportal.log
else
  cat $PTMP/resource.csv | grep urn:publicid:IDN | 
    while IFS= read -r line
    do
      resource_id=`echo $line | cut -d, -f1`
      client_id=`echo $line | cut -d, -f2`
      if [ "$client_id" == "null" ]; then
        host=$client_id
      else 
        host="`echo $client_id | cut -d+ -f4`.`echo $client_id | cut -d+ -f2`"
      fi 
      #echo "$resource_id ---- $host"
      cp "$PTMP/$resource_id.csv"  "$FINAL_DEST/$host.csv"
    done
fi
wc -l $FINAL_DEST/*
