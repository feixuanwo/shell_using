#!/bin/bash

#author:zhangyong
#date:20161209
#description:格式说明脚本
#location:/home/weblogic/shell/normal/
#document:脚本规范化文档.doc

. ~/.bash_profile


#常量定义示例
SHELL_PATH="/home/weblogic/shell/normal/"      #脚本路径
SHELL_NAME="format.sh"                         #脚本名
LOG_PATH="/home/weblogic/shell/normal/log/"    #日志路径
LOG_NAME="format.log"                          #日志名
LOCK_NAME=".format_lock"                       #锁文件

#变量定义示例
var_if=test         #if示例变量
var_while=a         #while示例变量
var_case=ttt        #case示例变量

#log函数，记录指定log内容
log()
{
    log_level=$1                        #第一个参数为数字，确定日志等级
    log_content=$2                      #第二个参数为日志内容
    log_levels=("INFO" "WARN" "ERROR")  #日志一共有3个等级
    echo "`date +%Y-%m-%d" "%H:%M:%S` [${log_levels[$log_level]}]:$log_content" >> ${LOG_PATH}$LOG_NAME
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

#if示例
if [ "$var_if" == "test" ] ; then
    echo "case1"
elif [ "$var_if" == "test2" ] ; then
    echo "case2"
else
    echo "case3"
fi

[ "$var_if" == "test2" ] && echo case1 || echo case2


#while示例
while [ "$var_while" == "test2" ]
do
    var_while=test3
done

while (($i < 100))
do
    echo i:$i
    ((i++))
done


#for示例
for ((i = 0; i <= 100; i++))
do
    echo i:$i
done

for i in a b c d e
do
    echo i:$i
done


#case示例
case $var_case in 
    aaa)
        echo "case1"
        ;;
    ttt)
        echo "case2"
        ;;
    *)
        echo "other case"
        ;;
esac

releaseLock


