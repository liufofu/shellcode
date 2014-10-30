#!/usr/bin/env python
#coding=utf-8
##########################################
# author        www.liufofu.com
# email         14158286@qq.com
# date          2014-10-29
######### descprition ##################
#通过python发送邮件
# 1. smtplib模块
# fix 邮件标题乱码问题，通过email.header来解决
# fix 可以设置发送文本或html邮件
# fix 图片填充到内容中去显示
# add 附件发送方式
# 2. email模块
########################################
import sys
import smtplib
import time
from email.mime.text import MIMEText
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
#某些邮件接收后，标题乱码
from email.header import Header

"""
_subtype 用于控制发送的类型
plain : 发送文本邮件
html:发送html邮件
"""
def sendmail (authinfo, fromadd, toadd, subject, context,imglist,ishtml=0, character="utf-8"):
	#获取邮件服务器，用户名，密码信息
	mailserver=authinfo.get('server')
	mailuser=authinfo.get('username')
	mailpassword=authinfo.get('password')
	#判断所提交的基础信息是否完善
	if not(mailserver and mailuser and mailpassword):
		print "server information incomplete"
		sys.exit()
	
	msgroot=MIMEMultipart('related')
	msgroot['Subject']=Header(subject,"utf-8")
	msgroot['From']=fromadd
	msgroot['To']=";".join(toadd)
	msgAlternative=MIMEMultipart('alternative')
	#设定纯文本或html信息
	if ishtml==1:
		msgtext=MIMEText(context,_subtype="html",_charset=character)
	else:
		msgtext=MIMEText(context,_subtype="plain",_charset=character)
	msgroot.attach(msgAlternative)
	msgAlternative.attach(msgtext)

	#设置图片信息
	if len(imglist)>0 :
		imgnum=0
		for img in imglist:
			fp=open(img,'rb')
			msgimage=MIMEImage(fp.read())
			fp.close()
			msgimage.add_header('Content-ID', '<image'+str(imgnum)+'>')
			msgroot.attach(msgimage)
			imgnum=imgnum+1
		
	"""	
	#发送图片内容
	fp = open(r'C:\Users\liufofu\Desktop\db.png', 'rb')
	msgimage = MIMEImage(fp.read())
	fp.close()
	msgimage.add_header('Content-ID', '<image1>')
	msgroot.attach(msgimage)
	"""

	"""
	#发送附件内容
	att1 = MIMEText(open('d:\\123.rar', 'rb').read(), 'base64', 'gb2312')
	att1["Content-Type"] = 'application/octet-stream'
	att1["Content-Disposition"] = 'attachment; filename="123.doc"'#这里的filename可以任意写，写什么名字，邮件中显示什么名字
	msg.attach(att1)
	"""
	#开始发送邮件
	try:
		server=smtplib.SMTP()
		server.connect(mailserver)
		server.login(mailuser,mailpassword)
		server.sendmail(fromadd,toadd,msgroot.as_string())
		server.close()
		return True
	except Exception ,e:
		print str(e)
		return False


if __name__=="__main__":
	authinfo={}
	authinfo['server']="smtp.163.com"
	authinfo['username']="xxxx"
	authinfo['password']="xxxx"
	fromadd="xxx@xxx.com"
	toadd=["xxx@xxx.com"]
	subject="xxx测试文档"
	
	ishtml=1
	imgstr=""
	imglist=[r'C:\Users\liufofu\Desktop\db.png',r'C:\Users\liufofu\Desktop\db.png']
	for i in range(len(imglist)):
		imgstr+="""<img src="cid:image%d">""" %i
		
	context="若存在文件，请联系<a href='http://www.liufofu.com'>liufofu</a>，详细查看附件 "+imgstr
	print context

	if sendmail(authinfo,fromadd,toadd,subject,context,imglist,1):
		print "Send Successfully~~"
	else:
		print "Send Failure~~"
	





