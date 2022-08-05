#!/bin/bash
OUT=/dev/stderr
echo "starting PID $$" > $OUT
timeout 30 sh < /dev/stdin >> $OUT 2>&1 &
[[ $? == 0 ]] && echo "started PID $$" >> $OUT
