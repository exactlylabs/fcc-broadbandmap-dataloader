#!/bin/bash

set -e

psql workspace -f ./create.sql

FILES="./working/*"
for FILE in $FILES
do
  mkdir -p tmp

  unzip $FILE -d ./tmp

  # Should just be 1 csv per zip
  DATA_FILE=$(find ./tmp -type f -name "*.csv" | tail -n 1)
  psql workspace -c "\copy bdc FROM '$DATA_FILE' WITH (FORMAT CSV, HEADER)"

  rm -r tmp
done
