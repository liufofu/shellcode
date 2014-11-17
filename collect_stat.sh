#! /bin/sh

###########################################################
# Copyright (c) 2012, Heng.Wang. All rights reserved.
# Modified by Niss.Zhou on July 14 2014. The WorldCup is over
# This program is benifit for sysbench oltp test.
###########################################################

# set -x

# Get the key value of input arguments format like '--args=value'.
get_key_value()
{
    echo "$1" | sed 's/^--[a-zA-Z_-]*=//' 
}

# Usage will be helpful when you need to input the valid arguments.
usage()
{
cat <<EOF
Usage: $0 [configure-options]
  -?, --help Show this help message.
  --mysqldir=<> Set the mysql directory
  --sysbenchdir=<> Set the sysbench directory 
  --host=<> Set the host name.
  --port=<> Set the port number.
  --database=<> Set the database to sysbench.
  --user=<> Set the user name.
  --password=<> Set the password.
  --socket=<> Set the socket file
  --tablesize=<> Set the table seize.
  --engine=<> Set the sysbench engine.
  --threads=<> Set the threads number.
  --max-requests=<> Set the max request numbers.
  --max-time=<> Set the max run time.
  --var=<> Set the variable.
  --value=<> Set the value of the variable. 
  -p,--prepare Set the prepare procedure.
  -r,--run Set the run procedure.
  -c,--cleanup Set the cleanup procedure.
  --count=<>    Set collect COUNT times.
  --interval=<> Set INTERVAL.
  --outputdir=<> Set the output directory. 
  --func=<>      set the function to execute, as sysbench_oltp:c_global_stat:c_mysql_vars:innodb_stat.

Note: this script is intended for internal use by developers.

EOF
}

# Print the default value of the arguments of the script.
print_default()
{
cat <<EOF
  The default value of the variables:
  mysqldir $MYSQLDIR
  sysbenchdir $SYSBENCHDIR
  host $HOST
  port $PORT
  database $DATABASE
  user $USER
  password $PASSWORD
  socket $SOCKET
  tablesize $TABLESIZE
  engine $ENGINE
  threads $THREADS
  max-requests $REQUESTS
  max-time $TIME
  var $VAR
  value $VALUE
  prepare FALSE
  run TRUE
  cleanup     FALSE
  count $COUNT
  interval $INTERVAL
  outputdir $OUTPUTDIR
  func      $FUNCTION

EOF
}

# Parse the input arguments and get the value of the input argument.
parse_options()
{
  while test $# -gt 0
  do
    case "$1" in
    --mysqldir=*)
      MYSQLDIR=`get_key_value "$1"`;; 
    --sysbenchdir=*)
      SYSBENCHDIR=`get_key_value "$1"`;;
    --host=*)
      HOST=`get_key_value "$1"`;;
    --port=*)
      PORT=`get_key_value "$1"`;;
    --database=*)
      DATABASE=`get_key_value "$1"`;;
    --user=*)
      USER=`get_key_value "$1"`;;
    --password=*)
      PASSWORD=`get_key_value "$1"`;;
    --socket=*)
      SOCKET=`get_key_value "$1"`;;
    --tablesize=*)
      TABLESIZE=`get_key_value "$1"`;;
    --engine=*)
      ENGINE=`get_key_value "$1"`;;
    --threads=*)
      THREADS=`get_key_value "$1"`;;
    --max-requests=*)
      REQUESTS=`get_key_value "$1"`;;
    --max-time=*)
      TIME=`get_key_value "$1"`;;
    --var=*)
      VAR=`get_key_value "$1"`;;
    --value=*)
      VALUE=`get_key_value "$1"`;;
    --count=*)
      COUNT=`get_key_value "$1"`;;
    --interval=*)
      INTERVAL=`get_key_value "$1"`;;
    -p | --prepare)
      PREPARE=1;;
    -r | --run)
      RUN=1;;
    -c | --cleanup)
      CLEANUP=1;;
    --outputdir=*)
      OUTPUTDIR=`get_key_value "$1"`;;
    --func=*)
      FUNCTION=`get_key_value "$1"`;;
    -? | --help)
      usage
      print_default
      exit 0;;
    *)
      echo "Unknown option '$1'"
      exit 1;;
    esac
    shift
  done
}

# Sysbench prepare procedure, that generated the test data and sysbench environment. 
prepare()
{
  $SYSBENCH --test=oltp --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER \
  --mysql-password=$PASSWORD --mysql-socket=$SOCKET --mysql-db=$DATABASE \
  --mysql-table-engine=$ENGINE --oltp-table-size=$TABLESIZE prepare
  if [ $? -ne 0 ]
  then 
    echo "Exit with error when prepare procedure!" 
    exit -1 
  fi
}

# Sysbench run procedure, that test the mysql server with the given argments.
run()
{
  $SYSBENCH --test=oltp --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER \
  --mysql-password=$PASSWORD --mysql-socket=$SOCKET --mysql-db=$DATABASE \
  --mysql-table-engine=$ENGINE --oltp-table-size=$TABLESIZE --num-threads=$THREADS \
  --max-requests=$REQUESTS --max-time=$TIME run 
  if [ $? -ne 0 ] 
  then 
    echo "Exit with error when run procedure!" 
    exit -1
  fi
}

# Sysbench cleanup procedure, that cleanup the environment of sysbench test.
cleanup()
{
  $SYSBENCH --test=oltp --mysql-host=$HOST --mysql-port=$PORT --mysql-user=$USER \
  --mysql-password=$PASSWORD --mysql-socket=$SOCKET --mysql-db=$DATABASE \
  --mysql-table-engine=$ENGINE cleanup
}

#Sysbench online trans process
sysbench_oltp()
{
  SYSBENCH=$SYSBENCHDIR/bin/sysbench
    
  # If the mysql and sysbench executable program is not exist, exit the script.
  # Or, run the sysbench test.
  if [ -f $SYSBENCH ]
  then
    # If the output directory is not exist, then make directory.
    [[ -d $OUTPUTDIR ]] || mkdir -p $OUTPUTDIR
    
    # Print the current value of the script arguments.
    print_default | tee ${OUTPUTDIR}/sysbench_${VAR}_${VALUE}_thread_${THREADS}.cnf 
  
    if [ $PREPARE -ne 1 ] && [ $RUN -ne 1 ] && [ $CLEANUP -ne 1 ]
    then
      echo "Please be ensure you operation for sysbench test,the operations are" 
      echo "[--prepare| --run| --cleanup]."
      exit 1
    fi
    
    if [ $PREPARE -eq 1 ]
    then
      # Cleanup the environment and the test data of the sysbench.
      cleanup
      # Prepare the environment and the test data for sysbench.
      prepare
    fi
    
    if [ $RUN -eq 1 ]
    then
      # Running the sysbench test.
      run | tee ${OUTPUTDIR}/sysbench_${VAR}_${VALUE}_thread_${THREADS}.res
    fi
    
    if [ $CLEANUP -eq 1 ]
    then
      # Cleanup the environment and the test data of the sysbench.
      cleanup
    fi
    
  else 
    echo "$SYSBENCH is not exist!"
    echo "Please check the sysbench home directory."
    exit -1 
  fi
}

#collect global status
c_global_stat()
{
  MYSQLADMIN=$MYSQLDIR/bin/mysqladmin
  
  # If the mysqladmin is not exist, exit the script.
  if [ -f $MYSQLADMIN ]
  then
    # If the output directory is not exist, then make directory.
    [[ -d $OUTPUTDIR ]] || mkdir -p $OUTPUTDIR
    
    cd $MYSQLDIR
    ./bin/mysqladmin --host=$HOST --port=$PORT --user=$USER --password=$PASSWORD --socket=$SOCKET ext -i${INTERVAL} -c${COUNT} | tee ${OUTPUTDIR}/global_status_interval_${INTERVAL}_${HOST}_${PORT}.stat
      
  else 
    echo "$MYSQLADMIN is not exist!"
    echo "Please check the mysql home directory."
    exit -1
  
  fi
}

#print mysql variables
c_mysql_vars()
{
  MYSQLADMIN=$MYSQLDIR/bin/mysqladmin
  
  # If the mysqladmin is not exist, exit the script.
  if [ -f $MYSQLADMIN ]
  then
    # If the output directory is not exist, then make directory.
    [[ -d $OUTPUTDIR ]] || mkdir -p $OUTPUTDIR
      
      cd $MYSQLDIR
      ./bin/mysqladmin --host=$HOST --port=$PORT --user=$USER --password=$PASSWORD --socket=$SOCKET variables |tee  ${OUTPUTDIR}/mysql_vars_${HOST}_${PORT}.var
      
  else 
    echo "$MYSQLADMIN is not exist!"
    echo "Please check the mysql home directory."
    exit -1
  
  fi
}

#collect innodb status
innodb_stat()
{
  MYSQL=$MYSQLDIR/bin/mysql
  
  # If the mysql is not exist, exit the script.
  if [ -f $MYSQL ]
  then
    # If the output directory is not exist, then make directory.
    [[ -d $OUTPUTDIR ]] || mkdir -p $OUTPUTDIR
  
  ## The MySQL will exit while the lsn never vary within the 10 times.
  # Record the innodb engine status all the time.
    while true
    do 
      $MYSQL --host=$HOST --port=$PORT --user=$USER --password=$PASSWORD --socket=$SOCKET -e "SHOW ENGINE INNODB STATUS\G" | tee ${OUTPUTDIR}/innodb_stat_interval_${INTERVAL}_${HOST}_${PORT}.stat
      sleep $INTERVAL
    done
  
  else 
    echo "$MYSQL is not exist!"
    echo "Please check the mysql home directory."
    exit -1
  
  fi
}

#############################################################
# Define the variables the script used for executing.
MYSQLDIR=/usr/local/mysql
SYSBENCHDIR=/opt/sysbench
HOST=127.0.0.1
PORT=3306
DATABASE=test
USER=root
PASSWORD=123321
SOCKET=/log/run/mysql.sock
TABLESIZE=10000
ENGINE=innodb
THREADS=1
REQUEST=10000
TIME=1000
VAR="full"
VALUE="default"
PREPARE=0
CLEANUP=0
RUN=0
COUNT=5
INTERVAL=1
#FUNCTION="sysbench_oltp:c_global_stat:c_mysql_vars:innodb_stat"
FUNCTION="c_mysql_vars"
FUNS=
OUTPUTDIR=/opt/output


# Call the parse_options function to parse the input arguments.
parse_options "$@"

# Define the sysbench executable program.
#FUNCTION=${FUNCTION//:/" "}
FUNS=${FUNCTION//:/" "}
for i in ${FUNS}; do
  case "$i" in
    sysbench_oltp)
      sysbench_oltp ;;
    c_global_stat)
      c_global_stat ;;
    c_mysql_vars)
      c_mysql_vars ;;
    innodb_stat)
      innodb_stat ;;   
    *)
      echo "Unknown option '$1'"
      exit 1;;
    esac 
done

echo "The test is successfully finished!"
echo "----------------------------------"
exit 0
