#!/bin/bash

set -e

export STORAGE_DIRECTORY="${STORAGE_DIRECTORY:=./storage}"
export SIMULATED_USER_AGENT="${SIMULATED_USER_AGENT:=user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36}"

# Working variables, don't change these

export METADATA_DIR=$STORAGE_DIRECTORY/metadata
export FILES_DIR=$STORAGE_DIRECTORY/files
export INDEX_FILE_PATH=$STORAGE_DIRECTORY/index.csv
export LOG_FILE_PATH=$STORAGE_DIRECTORY/sync.log
