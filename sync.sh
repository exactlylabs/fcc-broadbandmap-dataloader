#!/bin/bash

set -e

# Configuration
MY_DIRECTORY=$(dirname "${BASH_SOURCE[0]}")
source $MY_DIRECTORY/config.sh

# Working variables
FILING_ENDPOINT=https://broadbandmap.fcc.gov/nbm/map/api/published/filing
MAP_PROCESSING_UPDATES_ENDPOINT=https://broadbandmap.fcc.gov/api/reference/map_processing_updates/NBM_PROCESS_ID
FILE_INDEX_ENDPOINT=https://broadbandmap.fcc.gov/nbm/map/api/national_map_process/nbm_get_data_download/NBM_PROCESS_ID
FILE_DOWNLOAD_ENDPOINT=https://broadbandmap.fcc.gov/nbm/map/api/getNBMDataDownloadFile/FILE_ID/1

EPOCH=$(date +%s)

FILING_META_FILENAME=$EPOCH-filings.json

# Prep work

mkdir -p $METADATA_DIR $FILES_DIR
touch $INDEX_FILE_PATH

# Define helpers

fetch_and_store() {
  URL=$1
  DEST_FOLDER=$2
  DEST_FILE=$3

  if [ -z "$DEST_FILE" ]
  then
    curl -s -H "${SIMULATED_USER_AGENT}" --output-dir "${DEST_FOLDER}" -OJ $URL
  else
    curl -s -H "${SIMULATED_USER_AGENT}" -o "${DEST_FOLDER}/${DEST_FILE}" $URL
  fi
}

sync_files() {
  PROCESS_ID=$1
  LAST_UPDATED_DATE=$2

  FILING_INDEX_FILENAME="${EPOCH}-${PROCESS_ID}-filing-index.json"
  SYNC_DIRECTORY="${FILES_DIR}/${PROCESS_ID}/${LAST_UPDATED_DATE}"
  FILE_INDEX_ENDPOINT_W_PID="${FILE_INDEX_ENDPOINT/NBM_PROCESS_ID/$PROCESS_ID}"
  
  mkdir -p $SYNC_DIRECTORY

  fetch_and_store "${FILE_INDEX_ENDPOINT_W_PID}" "${METADATA_DIR}" "${FILING_INDEX_FILENAME}"

  FILE_IDS_IN_REMOTE_INDEX=$(jq --raw-output '.data[] | select(.provider_id == null) | .id' "${METADATA_DIR}/${FILING_INDEX_FILENAME}")

  FILES_TO_FETCH=()
  PRIOR_FETCHED_COUNT=0
  for FILE_ID in ${FILE_IDS_IN_REMOTE_INDEX}; do
    FILE_INDEX_SIGNATURE="${PROCESS_ID},${LAST_UPDATED_DATE},${FILE_ID}"
    if grep -Fq "$FILE_INDEX_SIGNATURE" $INDEX_FILE_PATH
    then
      let "PRIOR_FETCHED_COUNT+=1"
    else
      FILES_TO_FETCH+=($FILE_ID)
    fi
  done

  echo "Previously fetched ${PRIOR_FETCHED_COUNT} of $(wc -l <<< "$FILE_IDS_IN_REMOTE_INDEX" | tr -d '[:space:]')"
  echo "Syncing remaining files now..."
  for FILE_ID in "${FILES_TO_FETCH[@]}"
  do
    FILE_DOWNLOAD_ENDPOINT_W_FILE_ID="${FILE_DOWNLOAD_ENDPOINT/FILE_ID/$FILE_ID}"
    
    # Note, we're not preserving the specified filename for code simplicity
    # but also because we have the original metadata linking the id to the
    # filename if needed
    fetch_and_store "$FILE_DOWNLOAD_ENDPOINT_W_FILE_ID" "$SYNC_DIRECTORY" "${FILE_ID}.zip"

    unzip -t "$SYNC_DIRECTORY/$FILE_ID.zip" >> $LOG_FILE_PATH

    echo "${PROCESS_ID},${LAST_UPDATED_DATE},${FILE_ID},${EPOCH}" >> $INDEX_FILE_PATH

    let "PRIOR_FETCHED_COUNT+=1"
    echo "Fetched ${PRIOR_FETCHED_COUNT} of $(wc -l <<< "$FILE_IDS_IN_REMOTE_INDEX" | tr -d '[:space:]')"
  done
}

sync_filing() {
  PROCESS_ID=$1

  FILING_UPDATE_FILENAME="${EPOCH}-${PROCESS_ID}-filing-updates.json"
  MAP_PROCESSING_UPDATES_ENDPOINT_W_PID="${MAP_PROCESSING_UPDATES_ENDPOINT/NBM_PROCESS_ID/$PROCESS_ID}"

  echo "Syncing Process ID ${PROCESS_ID}"

  fetch_and_store "${MAP_PROCESSING_UPDATES_ENDPOINT_W_PID}" "${METADATA_DIR}" "${FILING_UPDATE_FILENAME}"
  LAST_UPDATED_DATE=$(jq --raw-output ".data[0].last_updated_date" "${METADATA_DIR}/${FILING_UPDATE_FILENAME}")

  sync_files "${PROCESS_ID}" "${LAST_UPDATED_DATE}"
}

# Index is a CSV with the following columns
# * Filing Process ID
# * Filing Last Updated Date
# * File ID
# * Fetched at Epoch
# 
# Items are written to this index when successfully downloaded
# and verified via unzip -t. Once written to the index, the file
# will be assumed to be fetched and further attempts will not be made.

fetch_and_store "${FILING_ENDPOINT}" "${METADATA_DIR}" "${FILING_META_FILENAME}"

PROCESS_IDS=$(jq --raw-output ".data[].process_uuid" ${METADATA_DIR}/${FILING_META_FILENAME})

for PID in ${PROCESS_IDS}; do
  sync_filing "${PID}"
done
