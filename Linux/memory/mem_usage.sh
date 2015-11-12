#!/bin/bash
#
# Thorsten Bruhns (Thorsten.Bruhns@opitz-consulting.de)
#
# This script is experimental at the moment
# swap is ignored in memory total at the moment
# some more tests are needed to get correct data
# this script works only on Linux!
#
# Date: 12.11.2015
MEMINFO=/proc/meminfo

get_info() {
    typ=$1
    cat $MEMINFO | grep ^$typ | awk '{print $2}'
}

MemTotal=$(get_info MemTotal:)
MemFree=$(get_info MemFree:)
Cached=$(get_info Cached:)
Buffers=$(get_info Buffers:)
PageTables=$(get_info PageTables)
SHmem=$(get_info Shmem)

# if SHmem is not availible. Try to calculate the shared memory from ipcs and df
if [ ${SHmem:--1} = -1 ] ; then
    devshm=$(df | grep "/dev/shm$" | awk '{print $3}')

    shmsum=0
    for memseg in $(ipcs -m | awk '{print $5}' | grep "^[0-9]") 
    do 
      shmsum=$(($shmsum+($memseg/1024)))
    done
    SHmem=$(($devshm+$shmsum))
fi

echo "Memory size is in kb"
echo "MemTotal     "$MemTotal
echo "MemFree      "$MemFree
caches=$(($Cached+$Buffers))
echo "cache+buffer "$caches
echo "PageTables   "$PageTables
echo "Shared Mem   "$SHmem

allused=$((($MemTotal-$MemFree-$caches+$SHmem+$PageTables)/1024))
echo "Summary used (MB): "$allused
