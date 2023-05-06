#!/bin/bash

set -e

psql workspace -f ./create.sql

FILES="./working/state/*"
for FILE in $FILES
do
  mkdir -p tmp

  unzip $FILE -d ./tmp

  # Should just be 1 csv per zip
  DATA_FILE=$(find ./tmp -type f -name "*.csv" | tail -n 1)
  psql workspace -c "\copy bdc FROM '$DATA_FILE' WITH (FORMAT CSV, HEADER)"

  rm -r tmp
done

FILES="./working/national/*"
for FILE in $FILES
do
  mkdir -p tmp

  unzip $FILE -d ./tmp
  DATA_FILE=$(find ./tmp -type f -name "*.csv" | tail -n 1)
  psql workspace -c "\copy bdc_summary FROM '$DATA_FILE' WITH (FORMAT CSV, HEADER)"

  rm -r tmp
done
