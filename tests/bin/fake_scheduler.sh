#!/bin/bash
OUT=/dev/null
echo "starting $$" > $OUT
timeout 30 bash < /dev/stdin > $OUT 2>&1 &
[[ $? == 0 ]] && echo "started $$" >> $OUT
