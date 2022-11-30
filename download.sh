#!/bin/bash

set -e

export NBM_PROCESS_ID=$(curl https://broadbandmap.fcc.gov/nbm/map/api/published/filing | jq --raw-output ".data[0].process_uuid")

export FILE_ID_LIST=$(curl https://broadbandmap.fcc.gov/nbm/map/api/national_map_process/nbm_get_data_download/$NBM_PROCESS_ID | jq '.data[] | select(.data_type=="Fixed Broadband" and .state_fips!=null) | .id')

mkdir -p ./working

while IFS= read -r FILE_ID; do
    curl -OJ --output-dir ./working https://broadbandmap.fcc.gov/nbm/map/api/getNBMDataDownloadFile/$FILE_ID/1
done <<< "$FILE_ID_LIST"
