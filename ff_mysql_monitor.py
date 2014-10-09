#coding=utf-8
#!/usr/bin/env python

'''
���ܣ��ɼ�mysq������Ϣ
author:www.liufofu.com
date:2014-07-12
email:14158286@qq.com


˼·��ģ��orzdba���ߣ����ǻ����ڱȽϵͼ��İ汾���д���һ���ļ���
0�������д��ݲ������ű��У�ͨ��getopt����ʽ�������в���
1��ͨ��python��MySQLdbģ�����ӵ�mysql server
2��ִ��sql��䣬show global  status,show global variables��ȡ��Ӧ�ı�����python�ֵ���
3��ͨ���ж�-c�����Ƿ���ڵ�ǰ�ĵ��ô��������ж��Ƿ����ִ�нű�,-i�������ڿ��ƽű����õ�Ƶ��
4����ʽ�������Ӧ�Ľ����

bugs:
1���������δ�ж��쳣
2��δ�ж����������Ƿ�װ��MySQLdb
3���ű�����Python2.7.3�����������汾δ����
4��Ŀǰ��������Ƚϵ�һ���������������Ľ�
5������Ƚϻ��ң����ܻ���ĵ��������ѣ�����~~


#######################
���÷�ʽ liufofu@liufofu:~$ python ff_mysql_monitor.py -h localhost -u root -p 123456 -i 2 -c 11
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
        
    count=0 # mysql_count���ڿ��ƽű����ô���
    while count<int(mysql_count):
        valstatus_last=ffm.getvalues(sqlstatus)
        valvariables_last=ffm.getvalues(sqlvariables) 
        if count%10==0:
            print "%-10s\t%-10s\t\t%-20s\t\t%-20s\t\t%-15s\t%-15s" %("QPS","TPS","key_buffer_read_hits","key_buffer_write_hits","Thread Cache","Innodb Buffer") 
        time.sleep(int(mysql_intval)) # mysql_intval���ڿ��ƽű�sleepʱ��
        valstatus_now=ffm.getvalues(sqlstatus)
        valvariables_now=ffm.getvalues(sqlvariables) 
        mem_cache(valstatus_now,valstatus_last,valvariables_now,valvariables_last,int(mysql_intval))
        count=count+1