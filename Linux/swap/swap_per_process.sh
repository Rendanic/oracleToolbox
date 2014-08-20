#!/bin/bash
# 
# $Id: swap_per_process.sh 1114 2014-01-31 20:49:11Z tbr $
#
# Get current swap usage for all running processes
# only processes with swap space are listed
#
# Erik Ljungstrom 27/05/2011
# http://northernmost.org/blog/find-out-what-is-using-your-swap/
# 
# Thorsten Bruhns 31/01/2014
# added filter for processes with more then 0 Bytes swap space
#
# sort output: | sort -k5n

SUM=0
OVERALL=0
for DIR in `find /proc/ -maxdepth 1 -type d | egrep "^/proc/[0-9]"` ; do
	PID=`echo $DIR | cut -d / -f 3`
	PROGNAME=`ps -p $PID -o comm --no-headers`
	for SWAP in `grep Swap $DIR/smaps 2>/dev/null| awk '{ print $2 }'`
	do
		let SUM=$SUM+$SWAP
	done
	if [ $SUM -gt 0 ]
	then
		echo "PID=$PID - Swap used: $SUM - ($PROGNAME )"
	fi
	let OVERALL=$OVERALL+$SUM
	SUM=0
done
echo "Overall swap used: $OVERALL"
