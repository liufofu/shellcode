#!/bin/bash
#==============================================================================
#
#          FILE: sysbench_auto.sh
#
#         USAGE: ./sysbench_auto.sh
#
#   DESCRIPTION: This file is sysbench_auto.sh 
#        AUTHOR: Kevin Lu (kevin), kevin@gmail.com
#  ORGANIZATION: cmcc
#       CREATED: 02/26/2014 17:35
#      REVISION: v1.0.1
#==============================================================================
#init variables
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

ff_outputdir=/tmp/liufofu
curdate=$(date +%Y%m%d)
curtime=$(date +%H%M%S)
ff_logfile=${ff_outputdir}/${curdate}.log
ff_sysbenchdir=${ff_outputdir}/sysbench 


#处理过程中产生的日志由日志函数来进行处理记录
function log()
{
    echo "`date +"%Y-%m-%d %H:%M:%S"` $1 "  >> ${ff_logfile}
}

if [ ! -e ${ff_outputdir} ];then
    mkdir -p ${ff_outputdir}
    log "创建输出目录"
fi
if [ ! -e ${ff_sysbenchdir} ];then
    mkdir -p ${ff_sysbenchdir}
    log "创建sysbench输出目录"
fi
#begin size
for size in {8G,64G};do
    for mode in {seqwr,seqrewr,seqrd,rndrd,rndwr,rndrw};do
        for blksize in {4096,16384};do
            sysbench --test=fileio --file-num=64 --file-total-size=$size prepare
            for threads in {1,4,8,16,32};do
                log "=============testing $blksize in $threads threads"
                echo PARAS $size $mode $threads $blksize > ${ff_sysbenchdir}/sysbench-size-$size-mode-$mode-threads-$threads-blksz-$blksize
                for i in {1,2,3};do
                    sysbench --test=fileio --file-total-size=$size --file-test-mode=$mode --max-time=180 \
                    --max-requests=100000 --num-threads=$threads --init-rng=on --file-num=64 \
                    --file-extra-flags=direct --file-fsync-freq=0 --file-block-size=$blksize run \
                    |tee -a ${ff_sysbenchdir}/sysbench-size-$size-mode-$mode-threads-$threads-blksz-$blksize 2>&1
                done #end i
            done # end threads
        sysbench --test=fileio --file-total-size=$size cleanup
        done #end blksize
    done # end mode
done #end size