#!/bin/bash

#author:zhangyong
#date:20170111
#description:监控各队列接收者数量和滞留信息数
#location:/home/tibesb/shell/normal/
#document:暂无

. ~/.bash_profile

#路径相关
SHELL_PATH=/home/tibesb/shell/normal/	#脚本目录
TMP_PATH=/home/tibesb/shell/normal/tmp/	#临时文件存放目录
LOG_PATH=/home/tibesb/shell/normal/log/	#日志目录

#队列服务相关
TIBCO_PORT=7222				#tibco队列服务端口号
TIBCO_LOGIN_NAME=			#tibco队列服务用户名
TIBCO_PASSWD=				#tibco队列服务密码

#文件相关
TMP_FILE=.tibco_queues_info.tmp		#存放tibco所有队列信息文件
RCVRS_REF_TIBCO=.rcvrs_ref_tibco.list	#待监控接收者的队列存放文件
MONITOR_ISSUE=.monitor_issue.mail	#问题队列存放文件
LOCK_NAME=.monitor_revs.lock		#锁文件
LOG_NAME=monitor_revs.log		#日志文件

#清空队列相关
PURGE_START_TIME=00:08:00		#每日定时清空队列开始时间
PURGE_END_TIME=00:12:00			#每日定时清空队列结束时间
QUEUE_IGNORE=( "QTBLACK.OUT@QTBUS21" )
PURGE_QUEUES=( "MONITOR_CCB" "MONITOR_RYX" )		#需要被清空的队列

#邮件相关
MAIL_ADDRESS=zhangyong@imobpay.com	#收件人地址，以","分隔


is_started=				#队列是否启动
queue=					#具体队列名
date_now=`date -d "now" +%H:%M:%S`	#目前时间

#打印指定格式日志
log()
{
    log_level=$1                        #第一个参数为数字，确定日志等级
    log_content=$2                      #第二个参数为日志内容
    log_levels=("INFO" "WARN" "ERROR")  #日志一共有3个等级
    echo "`date +%Y-%m-%d" "%H:%M:%S` [${log_levels[$log_level]}]:$log_content" >> ${LOG_PATH}$LOG_NAME
}

#发送邮件
sendMail()
{
    [ `cat ${TMP_PATH}${MONITOR_ISSUE}|wc -l ` -ne 0 ] && cat ${TMP_PATH}${MONITOR_ISSUE}|mail -s "Tibco Monitor" $MAIL_ADDRESS
}

#清空单个队列
purgeQueue()
{
    purge_queue=$1
    expect >> ${LOG_PATH}$LOG_NAME <<EOF
    spawn bash -c "ems.admin"
    expect ">"
    send "connect\r"
    expect "Login name"
    send "$TIBCO_LOGIN_NAME\r"
    expect "Password"
    send "$TIBCO_PASSWD\r"
    expect "$TIBCO_PORT>"
    send "purge queue $purge_queue\r"
    expect "(yes,no)"
    send "yes\r"
    send "exit\r"
    expect eof
EOF
}

#加锁函数
getLock()
{
    touch ${SHELL_PATH}${LOCK_NAME}
}

#解锁函数
releaseLock()
{
    rm ${SHELL_PATH}${LOCK_NAME}
}


#判断脚本是否已被加锁
if [ -f ${SHELL_PATH}${LOCK_NAME} ] ; then
    echo "This shell has been locked"
    exit 1
else
    getLock
fi

> ${TMP_PATH}${MONITOR_ISSUE}

#查看队列服务是否启动
nc -z 127.0.0.1 $TIBCO_PORT > /dev/null 2>&1
is_started=$?

#如果未启动则直接发邮件然后退出
if [ $is_started -ne 0 ] ; then
    echo "Tibco service is down!" >> ${TMP_PATH}${MONITOR_ISSUE}
    log 2 "Tibco service is down!"
    sendMail
    exit
fi

#导出当前所有队列信息至文件
log 0 "Start to export the tibco queue snapshot"
expect >${TMP_PATH}${TMP_FILE} <<EOF
spawn bash -c "ems.admin"
expect ">"
send "connect\r"
expect "Login name"
send "$TIBCO_LOGIN_NAME\r"
expect "Password"
send "$TIBCO_PASSWD\r"
expect "$TIBCO_PORT>"
send "show queues\r"
expect "$TIBCO_PORT>"
send "exit\r"
expect eof
EOF
log 0 "Export over"

#如果没有监控接收者的队列文件则以当前队列信息为基准生成相应文件
[ -f ${TMP_PATH}${RCVRS_REF_TIBCO} ] || sed 's/^..//g' ${TMP_PATH}${TMP_FILE}|awk '{if((NF == 10)&&($4 != 0))print $1}'|grep -v ^\$TMP|sort > ${TMP_PATH}${RCVRS_REF_TIBCO}

#监控指定队列的接收者数量
log 0 "Start to monitor the queue receivers"
for queue in `cat ${TMP_PATH}${RCVRS_REF_TIBCO}`
do
    #如果该队列没有接收者则输出至文件
    sed 's/^..//g' ${TMP_PATH}${TMP_FILE}|awk '/'$queue'/{if(($1 == "'$queue'")&&($4 == 0))print "Tibco queue receiver lost:"$1}' >> ${TMP_PATH}${MONITOR_ISSUE}
done
log 0 "Queue receivers monitor over"

#查找消息数大于50的队列
log 0 "Start to monitor the queue messages"
sed 's/^..//g' ${TMP_PATH}${TMP_FILE}|awk '{if((NF == 10)&&(substr($1,0,1) != "$" )&&($5 >= 50))print "Tibco queue messages too much:"$1",Msgs:"$5}'|sed '1,2d' >> ${TMP_PATH}${MONITOR_ISSUE}
for((i = 0;i < ${#QUEUE_IGNORE[*]}; i++))
do
    sed -i '/^Tibco queue messages too much:'${QUEUE_IGNORE[$i]}',/d' ${TMP_PATH}${MONITOR_ISSUE}
done
log 0 "Queue messages monitor over"

#发送邮件
sendMail

#如果在规定时间内则清除指定队列
if [ `expr ${date_now//:/} - ${PURGE_START_TIME//:/}` -ge 0 ] && [ `expr ${date_now//:/} - ${PURGE_END_TIME//:/}` -le 0 ] ; then
    log 0 "Start to purge the queue,date_now:$date_now"
    for((i=0; i<${#PURGE_QUEUES[*]}; i++))
    do
        log 0 "Queue:${PURGE_QUEUES[$i]} purge messages"
        purgeQueue ${PURGE_QUEUES[$i]}
    done
else
    log 1 "Out of purge time"
fi

releaseLock
