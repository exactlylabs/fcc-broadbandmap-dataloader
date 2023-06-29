#!/bin/bash

set -e

NBM_PROCESS_ID=$(curl -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36' https://broadbandmap.fcc.gov/nbm/map/api/published/filing | jq --raw-output ".data[1].process_uuid")

RAW_JSON=$(curl -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36' https://broadbandmap.fcc.gov/nbm/map/api/national_map_process/nbm_get_data_download/$NBM_PROCESS_ID)

FILE_ID_LIST=$(echo $RAW_JSON | jq '.data[] | select(.data_type=="Fixed Broadband" and .state_fips!=null) | .id')
NATIONAL_SUMMARY_ID=$(echo $RAW_JSON | jq '.data[] | select(.data_type=="Broadband Summary by Geography Type") | .id')

mkdir -p ./working/states ./working/national

curl -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36' -OJ --output-dir ./working/national https://broadbandmap.fcc.gov/nbm/map/api/getNBMDataDownloadFile/$NATIONAL_SUMMARY_ID/1

while IFS= read -r FILE_ID; do
    curl -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36' -OJ --output-dir ./working/states https://broadbandmap.fcc.gov/nbm/map/api/getNBMDataDownloadFile/$FILE_ID/1
done <<< "$FILE_ID_LIST"
