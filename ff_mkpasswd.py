#!/usr/bin/env python
#coding=utf-8
##########################################
# author        www.liufofu.com
# email         14158286@qq.com
# date          2014-08-18
######### descprition ##################
# 按照规则生成随机密码
# 1、数字
# 2、小写字母
# 3、大写字母
# 4、大/小写字母
# 5、数字+小写字母
# 6、数字+大写字母
# 7、数字+大/小写字母
# 8、数字+大/小写字母+特殊字符
# 1.make random password
# 2. 
########################################
import sys
import string
import random

def print_usage():
    help_info='''
NAME:
ff_mkpasswd.py

SYNTAX:
ff_mkpasswd.py arg1 arg2

FUNCTION:
make random password

'''
def mk_random_passwd(rule,rlen):
	if rule==1:
		arylist=list(string.digits)
	elif rule==2:
		arylist=list(string.ascii_lowercase)
	elif rule==3:
		arylist=list(string.ascii_uppercase)
	elif rule==4:
		arylist=list(string.ascii_letters)
	elif rule==5:
		arylist=list(string.digits)+list(string.ascii_lowercase)
	elif rule==6:
		arylist=list(string.digits)+list(string.ascii_uppercase)
	elif rule==7:
		arylist=list(string.digits)+list(string.ascii_letters)
	elif rule==8:
		specialchar=['!','@','#','$','%','^','&','*','(',')','_','=','+','[',']','{','}','.','<','>','?']
		arylist=list(string.digits)+list(string.ascii_letters)+specialchar
	randpasswd=""
	i=0
	while i<rlen:
		rindex=int(random.random()*10000)%len(arylist)
		randpasswd=randpasswd+str(arylist[rindex])
		i=i+1
	return randpasswd


if __name__=='__main__':
    rlen=16
    rule=8
    if len(sys.argv)==3:
        if sys.argv[1].isdigit():
            rule=int(sys.argv[1])
        if sys.argv[2].isdigit():
            rlen=int(sys.argv[2])
    elif len(sys.argv)==2:
        if sys.argv[1].isdigit():
            rule=int(sys.argv[1])
    else:
        print_usage()
        sys.exit()
        

    print mk_random_passwd(rule,rlen)