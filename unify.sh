#!/bin/bash

set -e

# Configuration
MY_DIRECTORY=$(dirname "${BASH_SOURCE[0]}")
source $MY_DIRECTORY/config.sh

# Index is a CSV with the following columns
# * Filing Process ID
# * Filing Last Updated Date
# * File ID
# * Fetched at Epoch
# 
# Items are written to this index when successfully downloaded
# and verified via unzip -t. Once written to the index, the file
# will be assumed to be fetched and further attempts will not be made.

TEMP_DIR=$(mktemp -d)
UNZIP_TEMP_DIR=$TEMP_DIR/unzipped
mkdir -p $UNZIP_TEMP_DIR

if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

function cleanup {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

#HEADERS="process_id,version_date,source_file_id,frn,provider_id,brand_name,location_id,technology,max_advertised_download_speed,max_advertised_upload_speed,low_latency,business_residential_code,state_usps,block_geoid,h3_res8_id"
HEADERS="frn,provider_id,brand_name,location_id,technology,max_advertised_download_speed,max_advertised_upload_speed,low_latency,business_residential_code,state_usps,block_geoid,h3_res8_id"

LATEST_UPDATE_META_FILE=$(ls $METADATA_DIR | grep updates | sort -r | head -n 1)

TARGET_PROCESS_ID=$(jq --raw-output '.data[0].process_uuid' $METADATA_DIR/$LATEST_UPDATE_META_FILE)
TARGET_UPDATED_DATE=$(jq --raw-output '.data[0].last_updated_date' $METADATA_DIR/$LATEST_UPDATE_META_FILE)

TARGET_FILES_DIR=$FILES_DIR/$TARGET_PROCESS_ID/$TARGET_UPDATED_DATE

echo "Creating a unified export of Fixed Broadband data for process ID ${TARGET_PROCESS_ID}, last updated ${TARGET_UPDATED_DATE}"

LATEST_INDEX_FILE=$(ls $METADATA_DIR | grep index | sort -r | head -n 1)

FILE_IDS_FROM_INDEX=$(jq --raw-output '.data[] | select(.provider_id == null and .data_type == "Fixed Broadband") | .id' $METADATA_DIR/$LATEST_INDEX_FILE)

# Make sure all expected files are available locally
for FILE_ID in ${FILE_IDS_FROM_INDEX}; do
  FILE_INDEX_SIGNATURE="${TARGET_PROCESS_ID},${TARGET_UPDATED_DATE},${FILE_ID}"
  if ! grep -Fq "$FILE_INDEX_SIGNATURE" $INDEX_FILE_PATH
  then
    echo "Couldn't find a file downloaded with the index ${FILE_ID} for the given process id and updated date"
    exit 1
  fi
done

COUNT=0
echo $TEMP_DIR/output.csv
echo $HEADERS > $TEMP_DIR/output.csv
for FILE_ID in ${FILE_IDS_FROM_INDEX}; do
  ROW_PREFIX="${TARGET_PROCESS_ID},${TARGET_UPDATED_DATE},${FILE_ID},"
  
  unzip $TARGET_FILES_DIR/$FILE_ID.zip -d $UNZIP_TEMP_DIR >> $LOG_FILE_PATH
  DATA_FILE=$(find $UNZIP_TEMP_DIR -type f -name "*.csv" | tail -n 1)

  cat $DATA_FILE >> $TEMP_DIR/output.csv

  #while read LINE
  #do
  #  echo $LINE >> $TEMP_DIR/output.csv
  #done < <(tail -n +2 ${DATA_FILE})

  rm $DATA_FILE

  let "COUNT+=1"
  echo "Processed ${COUNT} of $(wc -l <<< "$FILE_IDS_FROM_INDEX" | tr -d '[:space:]')"
done

cp $TEMP_DIR/output.csv .
