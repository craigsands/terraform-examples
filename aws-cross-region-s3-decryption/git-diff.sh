#!/bin/bash

fileA='us-east-1.log'
fileB='us-east-2.log'

tmp_fileA="${fileA}.tmp"
tmp_fileB="${fileB}.tmp"

cat "${fileA}" |
  sed -E 's/^[0-9-]+ [0-9:]+,[0-9]{3} - //g' |
  sed -E 's/ at 0x[0-9a-z]+>/>/g' \
    >"${tmp_fileA}"

cat "${fileB}" |
  sed -E 's/^[0-9-]+ [0-9:]+,[0-9]{3} - //g' |
  sed -E 's/ at 0x[0-9a-z]+>/>/g' \
    >"${tmp_fileB}"

git diff --no-index "${tmp_fileA}" "${tmp_fileB}"

rm -f "${tmp_fileA}"
rm -f "${tmp_fileB}"
