 #!/bin/bash

#author:zhangyong
#date:20170113
#description:监控qtpay.prep_commun表和qtpay.tbv_sys_param表是否被改动
#location:/home/deve/zhangyong/git/Table_monitor
#document:暂无

. ~/.bash_profile
. /home/oracle/env/oracle.env
NLS_LANG="SIMPLIFIED CHINESE_CHINA.ZHS16GBK" 

SHELL_PATH=/home/deve/zhangyong/git/Table_monitor/	#脚本所在目录
TMP_PATH=/home/deve/zhangyong/tmp/			#临时文件目录
FILE_PATH=/home/deve/zhangyong/file/			#文件目录
LOG_PATH=/home/deve/zhangyong/log/			#日志路径

LOCK_NAME=.table_monitor.lock				#锁文件
MONITOR_ISSUE=.table_monitor.mail			#邮件内容保存文件
LOG_NAME=table_monitor.log				#日志名

DB_USER=qtmanager					#数据库用户名
DB_PASSWD=aaa111					#数据库密码
DB_NAME=orcl						#数据库名

MAIL_ADDRESS=zhangyong@imobpay.com      		#收件人地址，以","分隔


log()
{
    log_level=$1                        #第一个参数为数字，确定日志等级
    log_content=$2                      #第二个参数为日志内容
    log_levels=("INFO" "WARN" "ERROR")  #日志一共有3个等级
    echo "`date +%Y-%m-%d" "%H:%M:%S` [${log_levels[$log_level]}]:$log_content" >> ${LOG_PATH}$LOG_NAME
}

sendMail()
{
    [ `cat ${FILE_PATH}${MONITOR_ISSUE}|wc -l ` -ne 0 ] && cat ${FILE_PATH}${MONITOR_ISSUE}|mail -s "Table Monitor" $MAIL_ADDRESS
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

> ${FILE_PATH}${MONITOR_ISSUE}

sqlplus -S $DB_USER/$DB_PASSWD@$DB_NAME >>${LOG_PATH}$LOG_NAME <<EOF
set heading off
set linesize 999
set markup html off entmap on spool on preformat off 
set term off verify off feedback off pagesize 999 echo off
set colsep |
spool $FILE_PATH$MONITOR_ISSUE 
select *
  from ((select 'DELETE' OPERATION, pcm.*
          from qtmanager.prep_commun_monitor pcm
        minus
        select 'DELETE' OPERATION, pc.*
          from qtpay.prep_commun pc)
        union
        (select 'INSERT' OPERATION, pc.*
          from qtpay.prep_commun pc
        minus
        select 'INSERT' OPERATION, pcm.*
          from qtmanager.prep_commun_monitor pcm))
 order by id;
spool off
delete from qtmanager.prep_commun_monitor;
commit;
insert into qtmanager.prep_commun_monitor select * from qtpay.prep_commun;
commit;
exit
EOF
sed -i '/^$/d' $FILE_PATH$MONITOR_ISSUE 
sed -i 's/ //g' $FILE_PATH$MONITOR_ISSUE

for line in `cat $FILE_PATH$MONITOR_ISSUE`
do
    log 0 "$line"
    id=`echo $line|awk -F "|" '{print $2}'`
    flag=`awk -F "|" '{if($2 == '$id')print $0}' $FILE_PATH$MONITOR_ISSUE|wc -l`
    log 0 "id:$id flag:$flag"
    if [ $flag -gt 1 ] ; then
        sed -i 's/^INSERT|'$id'/UPDATE|'$id'/' $FILE_PATH$MONITOR_ISSUE
        sed -i '/^DELETE|'$id'/d' $FILE_PATH$MONITOR_ISSUE
    fi
done

sendMail

releaseLock
