#coding=utf-8
#!/usr/bin/env python

'''
功能：采集mysq运行信息
author:www.liufofu.com
date:2014-07-12
email:14158286@qq.com


思路：模仿orzdba工具，但是还处于比较低级的版本，有待进一步的加深
0、命令行传递参数到脚本中，通过getopt来格式化命令行参数
1、通过python的MySQLdb模块连接到mysql server
2、执行sql语句，show global  status,show global variables获取相应的变量到python字典中
3、通过判断-c参数是否大于当前的调用次数，来判断是否继续执行脚本,-i参数用于控制脚本调用的频率
4、格式化输出相应的结果集

bugs:
1、零除问题未判断异常
2、未判断主机环境是否安装了MySQLdb
3、脚本基于Python2.7.3开发，其他版本未测试
4、目前传入参数比较单一，还待后续继续改进
5、代码比较混乱，可能会恶心到不少朋友，哈哈~~


#######################
调用方式 liufofu@liufofu:~$ python ff_mysql_monitor.py -h localhost -u root -p 123456 -i 2 -c 11
#######################
'''

import MySQLdb
import os
import sys
import time
import getopt


def display_header():
    Headline='''\033[32;1m
		----------------------------------------------------------------
		This is a simple mysql monitor,if you have any bug information 
		Please report to lff642@gmail.com.
		And this is a Version 0.1
		----------------------------------------------------------------
		\033[0m'''
    print Headline




def print_usage():
    help_info='''NAME:
        mystat


 SYNTAX:
        mystat -i interval -c count -n statname


 FUNCTION:
        Report Status Information of MySQL


 PARAMETER:
     -i    interval interval time,default 1 seconds
     -c    count        times
     -n    name         statistics name
           contain: all,basic,innodb,myisam
                    traffic - Network Traffic
                    kbuffer - Key Buffer
                    qcache  - Query Cache
                    thcache - Thread Cache
                    tbcache - Table Cache
                    tmp     - Temporary Table
                    query   - Queries Statistics
                    select  - Select Statistics
                    sort    - Sort Statistics
                    innodb_bp - InnoDB Buffer Pool
      -d   disable      disable monitor name
           contain: var,innodb,none
      -h   Hostname
      -u   Username
      -p   Password
      '''
    print help_info


def mem_cache(valstatus_now,valstatus_last,valvariables_now,valvariables_last,intval):
    
    qps=(int(valstatus_now["Questions"])-int(valstatus_last["Questions"]))*1.0/intval
    tps=((int(valstatus_now["Com_commit"])+int(valstatus_now["Com_rollback"]))-(int(valstatus_last["Com_commit"])+int(valstatus_last["Com_rollback"])))*1.0/intval
    krh=(1-int(valstatus_now["Key_reads"])*1.0/int(valstatus_now["Key_read_requests"]))*100
    kwh=(1-int(valstatus_now["Key_writes"])*1.0/int(valstatus_now["Key_write_requests"]))*100
    tc=(1-int(valstatus_now["Threads_created"])*1.0/int(valstatus_now["Connections"]))*100
    ib=(1-int(valstatus_now["Innodb_buffer_pool_reads"])*1.0/int(valstatus_now["Innodb_buffer_pool_read_requests"]))*100
    print  "%-10.3f\t%-10.3f\t\t%-20.3f\t\t%-20.2f\t\t%-15.3f\t%-15.3f" %(qps,tps,krh,kwh,tc,ib)
   


class ffmysql():
    info={}
    def __init__(self,coninfo=None):
        self.info = coninfo
        #self.connect()
        
    def connect(self):
        '''
        mysql connect
        '''
        try:
            self.conn = MySQLdb.connect(host=self.info["host"],user=self.info["user"],passwd=self.info["passwd"],db=self.info["db"])
            #return self.conn.cursor
        except Exception, e:
            print "connect error %d  :  %s" %(e.args[0],e.args[1])
            sys.exit()
			
    def getvalues(self,sql):
        valdict={}
        cursor=self.conn.cursor()
        cursor.execute(sql)
        for line in  cursor.fetchall():
            valdict[line[0]]=line[1]
        
        return valdict
     
    def getvalue(self,sql):
		cursor=self.conn.cursor()
		cursor.execute(sql)
		return cursor.fetchone()
    #----------------------------------------------------------------------
    
    def insert(self,sql,var):
        """insert into data to mysql"""
        #cursor=self.
        cursor = self.conn.cursor()
        
        try:
            cursor.executemany(sql, val)
        except Exception, e:
            print e        

    def close(self):
	  try:
		  self.cursor.close()
		  self.conn.close()
	  except MySQLdb.Error ,e:
		 print "close error %d : %s"%(e.args[0],e.args[1])



if __name__ == "__main__":
    
    display_header()
    mysql_user=""
    mysql_password=""
    mysql_intval=""
    mysql_host=""
    mysql_count=0
    if len(sys.argv)>1:
        #print sys.argv[1:]
        pass
    else:
        print_usage()
        sys.exit()

    try:
        opts,value=getopt.getopt(sys.argv[1:],"h:i:c:o:u:p:")
        for opt,val in opts:
            if opt=="-h":
                mysql_host=val
            if opt=="-u":
                mysql_user=val
            if opt=="-i":
                mysql_intval=val
            if opt=="-p":
                mysql_password=val
            if opt=="-c":
					mysql_count=val    
    except getopt.GetoptError:
        print "Please check command option."
    
    #print mysql_host.strip(),mysql_user.strip(),mysql_password.strip()
    ffconfinfo={"host":mysql_host.strip(),"user":mysql_user.strip(),"passwd":mysql_password.strip(),"db":"mysql"}
    ffm=ffmysql(ffconfinfo)
    ffm.connect()
    sqlstatus="show global status ;"
    sqlvariables="show global variables;"
        
    count=0 # mysql_count用于控制脚本调用次数
    while count<int(mysql_count):
        valstatus_last=ffm.getvalues(sqlstatus)
        valvariables_last=ffm.getvalues(sqlvariables) 
        if count%10==0:
            print "%-10s\t%-10s\t\t%-20s\t\t%-20s\t\t%-15s\t%-15s" %("QPS","TPS","key_buffer_read_hits","key_buffer_write_hits","Thread Cache","Innodb Buffer") 
        time.sleep(int(mysql_intval)) # mysql_intval用于控制脚本sleep时长
        valstatus_now=ffm.getvalues(sqlstatus)
        valvariables_now=ffm.getvalues(sqlvariables) 
        mem_cache(valstatus_now,valstatus_last,valvariables_now,valvariables_last,int(mysql_intval))
        count=count+1