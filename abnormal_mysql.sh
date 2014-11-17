#!/bin/sh
###########################################################
# Copyright (c) 2013, Heng.Wang. All rights reserved.
###########################################################

# set -x
# Usage will be helpful when you need to input the valid arguments.
usage()
{
cat <<EOF
Usage: $0 [options]
  -h, --help                     Show this help message.
  -e <> | --env=<>               The environment of machine(0:online,1:normal,2:abnormal).
  -i <> | --install=<>           The install directory.
  -n <> | --num=<>               The instances number.
  -l <> | --log=<>               The binlog directory.
  -o <> | --output=<>            The runing information output file.
  -s <> | --step=<>              Runing from the given step.
                                   0:Checking the operation system.   
								   1:Initialize the data directory.  
								   2:Initialize the log directory.
								   3:Install the mysql and needed packages.
								   4:Setup os configure variables.
								   5:Initialize the instances.
  -d    | --daemon               Run in daemon mode.

Note: this script is intended for internal use by developers.

EOF
}

# Print the default value of the arguments of the script.
print_default()
{
cat <<EOF
  The default value of the variables:
  env        $ENVIRONMENT
  install    $INSTALL
  num        $INSTANCES
  log        $LOG
  output     $OUTPUT
  step       $STEP
  daemon     $DAEMON

EOF
}

# Parse the input arguments and get the value of the input argument.
parse_options()
{
  options=`getopt -o he:i:n:l:o:s:d:: --long help,env:,install:,num:,log:,output:,step:,daemon:: -n 'abnormal_mysql.sh' -- "$@"`
  if [ $? != 0 ] 
  then 
    usage 
    print_default
    exit 1 
  fi
  
  eval set -- "$options"

  while true
  do
    case "$1" in
      -e|--env)
        ENVIRONMENT=$2
        shift 2;;
      -i|--install)
        INSTALL=$2 
        shift 2;;
      -n|--num) 
        INSTANCES=$2
        shift 2 ;;
      -l|--log)
        LOG=$2
        shift 2;;
      -o|--output)
        OUTPUT=$2
        shift 2;;
      -s|--step)
        STEP=$2
        shift 2;;
      -d|--daemon)
        case "$2" in
          "") 
            DAEMON=1 
            shift 2 ;;          
          *)
            DAEMON=$2         
            shift 2 ;;
        esac ;;
      -h|--help)
        usage
        print_default
        exit 0;;
	  --)
	    shift
		break;;
      *) 
        echo "Unknown option '$1'"
        exit 1;;
    esac
  done
}


mem_check()
{
  memsum=0 #MB
  pass=0
  for folder in `ls ${INSTALL} | grep my`
  do
    if [ -f ${INSTALL}/${folder}/my.cnf ]; then
      mem=`grep -i "innodb_buffer_pool_size" ${INSTALL}/${folder}/my.cnf | cut -d "#" -f 1 | cut -d "=" -f 2 | tr A-Z a-z | sed "s# ##g" | sed "s#b##g"`
      if [ `echo ${mem} | grep g | wc -l` -eq 1 ]; then
        mem=`echo ${mem} | cut -d "g" -f 1` #GB
        memsum=`echo ${memsum}+${mem}*1024 | bc`
      elif [ `echo ${mem} | grep m | wc -l` -eq 1 ]; then
        mem=`echo ${mem} | cut -d "m" -f 1` #MB
        memsum=`echo ${memsum}+${mem} | bc`
      else
        msg="ERROR: cannot parse innodb buffer pool size in ${INSTALL}/${folder}/my.cnf"
        echo "$msg" ; 
        exit 4
      fi
    fi
  done

  mem=`echo ${innodb_buffer_pool_size} | cut -d "#" -f 1 | cut -d "=" -f 2 | tr A-Z a-z | sed "s# ##g" | sed "s#b##g"`
  if [ `echo ${mem} | grep g | wc -l` -eq 1 ]; then
    mem=`echo ${mem} | cut -d "g" -f 1` #GB
    memsum=`echo ${memsum}+${mem}*1024 | bc`
  elif [ `echo ${mem} | grep m | wc -l` -eq 1 ]; then
    mem=`echo ${mem} | cut -d "m" -f 1` #MB
    memsum=`echo ${memsum}+${mem} | bc`
  else
    msg="ERROR: cannot parse innodb buffer pool size in input parameter"
    echo "$msg" ; 
    exit 5
  fi

  memavail=`free -m | grep -i "Mem" | awk '{print $2}'`
  memavail=`echo "scale=0;${memavail}/1.25" | bc`
  if [ ${memsum} -gt ${memavail} ]; then
    msg="ERROR: memory (${memsum}/${memavail}) is not enough for new instance, quit"
    echo "$msg" ; 
    pass=0
  else
    pass=1
  fi
}

compute_innodb_buffer_pool_size()
{
  mem=`free -g | grep Mem | awk '{ print $2}'`
  innodb_buffer_pool_size=`echo $mem*0.79/$INSTANCES| bc -l | awk -F "." '{ print $1 }'`
  innodb_buffer_pool_size="${innodb_buffer_pool_size}G" 
}

gen_cnf()
{
    hostip=$IP
    a=`echo $hostip|cut -d\. -f1`
    b=`echo $hostip|cut -d\. -f2`
    c=`echo $hostip|cut -d\. -f3`
    d=`echo $hostip|cut -d\. -f4`
    server_id=`expr \( ${a} \* 256 \* 256 \* 256 + ${b} \* 256 \* 256 + ${c} \* 256 + ${d} \)`
    server_id=$((${server_id} << 6))
    server_id=`expr ${server_id} + \( ${port} % 64 \)`
    server_id=`expr ${server_id} % 4294967296`

    cat $1 | sed "s#PORT#${port}#g"                                                      > /tmp/my.cnf.temp1
    cat /tmp/my.cnf.temp1 | sed "s#INNODB_BUFFER_POOL_SIZE#${innodb_buffer_pool_size}#g" > /tmp/my.cnf.temp2
    cat /tmp/my.cnf.temp2 | sed "s#THREADBY4#16#g"             > /tmp/my.cnf.temp3
    cat /tmp/my.cnf.temp3 | sed "s#INNODB_IO_CAPACITY#1000#g"           > /tmp/my.cnf.temp4
    cat /tmp/my.cnf.temp4 | sed "s#SERVER_ID#${server_id}#g"                             > /tmp/my.cnf.temp5 #if not a number?
    cat /tmp/my.cnf.temp5 | sed "s#THREAD#8#g"                                > /tmp/my.cnf.result
}

init_instance()
{
  date
  #Init MySQL folder based on port######################################################
  msg="====Init port ${port}" && echo "$msg"
  rm -f ${INSTALL}/mybase/log/mysql-bin*
  if [ -d ${INSTALL}/my${port} -o -d ${LOG}/my${port} ]; then
    msg="ERROR: port ${port} has been initialized already!"
    echo "$msg" ; 
  else
    #mem_check
    #if [ ${pass} -eq 0 ];then
    #  msg="ERROR: fail to init base folder, quit the whole script"
    #  echo "$msg" ; 
    #  exit 6
    #fi
    
    echo "start copy mysql base file on $INSTALL"
    cp --preserve -rf ${INSTALL}/mybase ${INSTALL}/my${port}
    if [ -d ${LOG} ]; then
      msg="start copy mysql base file on log"
      echo "$msg"
      mkdir -p ${LOG}/my${port}
      cp -rf ${LOG}/mybase/log ${LOG}/my${port}/log
      rm -rf ${INSTALL}/my${port}/log
      ln -s ${LOG}/my${port}/log ${INSTALL}/my${port}/log
    fi
  fi

  #Generate my.cnf base on port########################################################
  gen_cnf /usr/mysqlmisc/support-files/mybase.cnf
  echo "gen my.cnf ok"
  cp /tmp/my.cnf.result ${INSTALL}/my${port}/my.cnf

  #Change owner of new folder, and start MySQL#########################################
  chown -R mysql:dba       ${INSTALL}/my${port} 
  [ -d ${LOG}/my${port} ] &&   chown -R mysql:dba  ${LOG}/my${port}
  echo | (mysqld_safe --defaults-file=${INSTALL}/my${port}/my.cnf --user=mysql --read_only  &)
  msg="start mysql $port instance,please waiting"
  echo "$msg"
  sleep 10
  tag=0
  for i in `seq 1 100`
  do
    num=`tail -n 5 ${INSTALL}/my${port}/log/alert.log|grep -i 'Source'|grep 'distribution'|grep -v grep |wc -l`
    if   [ $num -gt 0 ] ;then
      tag=1
      msg="mysqld $port start success"
      echo "$msg" 
      echo "====success"
    fi
    sleep 5
    [ $i -gt 199 ] && msg="mysqld $port can not start " &&  echo "$msg"  
    [ $tag -eq 1 ] && break
  done
    mysql -uroot -h127.0.0.1 -P$port -e "grant REPLICATION SLAVE,REPLICATION CLIENT,PROCESS, SHOW DATABASES on *.* to 'slave'@'%' IDENTIFIED BY  'slave';"
}

install()
{
  rpm -e `rpm -qa | grep mysql`
  rpm -e `rpm -qa | grep dbagent`
  rpm -e `rpm -qa | grep stargate`
  rpm -e `rpm -qa | grep backup`
  rm -fr /usr/lib/rpm/__db*
  yum clean all

  yum install mysql_package -y
  [ $? != 0 ] && echo "Install mysql package failed." && exit 1

  ###  todo_list: 具体方式删除了
  ln -s /usr/bin/mysqld_safe ${INSTALL}/mysql/bin/mysqld_unsafe
}

init_os()
{
    grubby --grub --update-kernel=ALL --args="numa=off"
    grubby --grub --update-kernel=ALL --args="elevator=deadline"
}

check()
{ 
  pidnum=`ps -ef|grep -Ei 'mysqld|asm|ora_dbw0|congo|vsear|redis|hbase|mongo|postmaster'|grep -v grep |wc -l`
  [ $pidnum -gt 0 ] && echo "have db pid" && exit 9
  [ -e ${INSTALL}/vsearch ] && echo "this is VSearch" && exit 9
  num=`ps -ef|grep congo|grep -v grep|wc -l`
  [ $num -gt 0 ] && echo "this is DRC" && exit 9
  num=`netstat -an|grep tcp|wc -l`
#  [ $num -gt 30 ] && echo "tcp session too much" && exit 9
  chmod +x $0
}

init_datadir()
{

  [ -z ${INSTALL} ] && echo "The install path is not exists." && exit 9
  [ -e "/data" ] && [ "${INSTALL}" != "/data" ] && echo "The /data is exists" && exit 9
  [ -d ${INSTALL} ] && [ "${INSTALL}" != "/data" ] && ln -s ${INSTALL} /data && echo "Link the /data directory."
  [ -d ${INSTALL} ] && num=`ls ${INSTALL} | grep my | wc -l` && [ $num -gt 0 ]  && echo "The install path has mysql directory." && exit 9
  INSTALL="/data"
}

check_logdir()
{
  num=`df -h | grep log | wc -l`
  if [ $num -eq 0 ]
  then
    rm -rf /log
  fi
}

#################################################################

ENVIRONMENT=2
INSTANCES=1
INSTALL="/data"
LOG="/log"
OUTPUT=/tmp/reinstall.log
IP=`hostname -i`
HOST=`hostname`
DAEMON=0
STEP=0

parse_options "$@"
if [ $STEP -eq 0 ]
then
  echo "Checking the operation system."
  check
  echo "[STEP 0] success"
  STEP=1
fi

if [ $DAEMON == 1 ]
then
    chmod 755 $0
    nohup $0 --step=1 $* --daemon=0 &>/tmp/reinstall.log &
    exit 0
fi

if [ $STEP -eq 1 ]
then
  echo "Initialize the data directory."
  init_datadir
  echo "[STEP 1] success"
  STEP=2
fi

if [ $STEP -eq 2 ]
then
  echo "Check log directory."
  check_logdir
  echo "[STEP 2] success"
  STEP=3
fi

if [ $STEP -eq 3 ]
then
  echo "Install the mysql and needed packages."
  install
  echo "[STEP 3] success"
  STEP=4
fi

if [ $STEP -eq 4 ]
then
  echo "Initialize os."
  init_os
  echo "[STEP 4] success"
  STEP=5
fi

if [ $STEP -eq 5 ]
then
  echo "Initialize the instances."
#  echo "compute innodb_buffer_pool_size."
  compute_innodb_buffer_pool_size 
#  echo "$innodb_buffer_pool_size"

  if [ $INSTANCES -lt 5 ]
  then
      ports=(3306 3406 3506 3606)
  else
      end=`expr \( ${INSTANCES} + 3401 \)`
      ports=(3306 3406 3506 3606 `seq 3401 $end`)
  fi
  
  pt_len=${#ports[@]}
  
  for i in `seq 1 $INSTANCES`
  do
      i=0
      while [ $i -lt $pt_len ];
      do
          port=${ports[$i]}
          tag=`ps -ef|grep mysqld|grep $port|grep -v grep|wc -l`
          [ $tag -lt 1 -o  ! -d ${INSTALL}/my$port ]   && break
          let i+=1
      done
      echo "$port init."
      init_instance
  done
  
  echo "[STEP 5] success"
  STEP=6
fi
if [ $STEP -eq 6 ]
then
  echo "All success"
fi










