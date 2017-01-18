#!/bin/bash
#author:shiye
#date:20170116
#function:FileTaskUtils服务监控，在指定时间内运行，超出指定时间自动关闭服务
#location:/home/qtservices/
#document:无 

. ~/.bash_profile

LOG_FILE="/home/qtservices/logs/FileTaskUtils_check.log"      #日志文件，记录日志输出的信息
SHELL_PATH="/home/qtservices/shell/normal/"                   #脚本路径
LOCK_NAME=".FileTaskUtils_lock"                               #锁文件
DATE_TIME=`date +%H%M`                                        #取系统当前时间，小时
START_TIME="0600"                                             #服务启动时间，小时  
END_TIME="0550"                                               #服务结束时间，小时

#检测函数，检测FileTaskUtils进程是否存在
#进程存在返回0；不存在返回1
check()
{
    SUM=`ps -ef | grep FileTaskUtils.jar | grep qtservices | grep -v grep | wc -l`
    if [ "$SUM" == "1" ] ; then
        return 0 
    else
        return 1
    fi
}

#日志函数
#log函数，记录指定log内容
log()
{
    log_level=$1                        #第一个参数为数字，确定日志等级
    log_content=$2                      #第二个参数为日志内容
    log_levels=("INFO" "WARN" "ERROR")  #日志一共有3个等级
    echo "`date +%Y-%m-%d" "%H:%M:%S` [${log_levels[$log_level]}]:$log_content" >> $LOG_FILE 
    return 0 
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

#脚本需要添加参数start来运行
if [ "$1" == "start" ] ; then
    #判断脚本是否已被加锁
    if [ -f ${SHELL_PATH}${LOCK_NAME} ] ; then
        echo "This shell has been locked"
        exit 1
    else
        getLock
    fi
    
    #启动服务
    if [ "$DATE_TIME" == "$START_TIME" ] ; then 
        #检测服务进程是否存在，不存在，启动服务
        check
        if [ "$?" == "1" ] ; then
            sh /home/qtservices/FileTaskUtils/startFileTaskServer.sh  
            log "1" "FileTaskUtils 服务未启动，已执行启动程序启动服务"
        fi
        sleep 5
        #再次检测服务是否启动成功
        check
        if [ "$?" == "0" ] ; then 
            log "0" "FileTaskUtils 服务已启动" 
        else 
            log "2" "FileTaskUtils 服务启动失败" 
            echo "FileTaskUtils 服务启动失败" | mail -s ERROR shiye@imobpay.com
        fi
    fi
    
    ##启动服务
    #if [ "$DATE_TIME" -lt "$END_TIME" ] ; then 
    #    #检测服务进程是否存在，不存在，启动服务
    #    check
    #    if [ "$?" == "1" ] ; then
    #        sh /home/qtservices/FileTaskUtils/startFileTaskServer.sh  
    #        log "1" "FileTaskUtils 服务未启动，已执行启动程序启动服务"
    #    fi
    #    sleep 5
    #    #再次检测服务是否启动成功
    #    check
    #    if [ "$?" == "0" ] ; then 
    #        log "0" "FileTaskUtils 服务已启动" 
    #    else 
    #        log "2" "FileTaskUtils 服务启动失败" 
    #        echo "FileTaskUtils 服务启动失败" | mail -s ERROR shiye@imobpay.com
    #    fi
    #fi
    
    #关闭服务
    if [ "$DATE_TIME" == "$END_TIME" ] ; then
        #输出日志
        log "0" "到达结束时间END_TIME:$END_TIME，准备关闭FileTaskUtils服务"
        #运行关闭脚本，关闭服务  
        sh /home/qtservices/FileTaskUtils/stopFileTaskServer.sh
        sleep 5
        #再次检测服务是否关闭，如未成功关闭，则采用杀进程关闭服务  
        check
        if [ "$?" == "0" ] ; then 
            log "1" "服务未正常关闭，将使用杀死进程方式关闭服务" 
            kill -9 `ps -ef | grep FileTaskUtils.jar | grep -v grep | awk '{print $2}'` 
        fi
        #再次检测服务，正常关闭，输出日志;未正常关闭，发送邮件报警  
        sleep 5
        check
        if [ "$?" == "1" ] ; then
            log "0" "FileTaskUtils 服务已关闭" 
        else
            log "2" "FileTaskUtils 服务未正常关闭，请手动关闭" 
            echo "FileTaskUtils 服务未正常关闭，请手动关闭" | mail -s ERROR shiye@imobpay.com
        fi
    fi
    
    #解锁
    releaseLock
else
    echo
    echo "========脚本需要添加参数“start”才可以运行========="
    echo
fi
