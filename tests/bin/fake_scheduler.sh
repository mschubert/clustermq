#!/bin/bash
echo "starting $$" > ~/worker.log
timeout 30 bash < /dev/stdin > ~/worker.log 2>&1 &
[[ $? == 0 ]] && echo "started $$" >> ~/worker.log
