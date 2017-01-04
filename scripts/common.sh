#!/bin/bash

alias LOG_INFO='loginner [INFO] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
alias LOG_WARN='loginner [WARN] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
alias LOG_ERROR='loginner [ERROR] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
alias ECHOANDINFO='echoAndLog [INFO] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
alias ECHOANDWARN='echoAndLog [WARN] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
alias ECHOANDERROR='errAndLog [ERROR] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'

shopt -s expand_aliases

loginner()
{
    log_file=$LOG_FILE
    if [ -z $log_file ]; then
	    echo "[$(date +'%Y-%m-%d %H:%M:%S') $*"
		return 0
	fi
	
	if [ -e $log_file ]; then
	    echo "[$(date +'%Y-%m-%d %H:%M:%S') $*" >> $log_file
	else
	    touch $log_file
		chmod 644 $log_file
		echo "[$(date +'%Y-%m-%d %H:%M:%S') $*" >> $log_file
	fi
}

echoAndLog()
{
    loginner "$*"
	level="$1"
	shift 3
	echo "$level $*"
}

errAndLog()

{
    loginner "$*"
	level="$1"
	shift 3
	echo -e "\e[31m$level $*\e[m"
}

die()
{
    ECHOANDERROR "$*"
	exit 1
}

putFile2Remote()
{
    local ip="$1"
    local pwd="$2"
    local src="$3"
    local dest="$4"

    LOG_INFO "Start sending $src to $ip..."
    $SCRIPTS_DIR/send.exp "$ip" "$pwd" "$src" "$dest" > /dev/null 2>&1
    ret="$?"
    
    if [ "$ret" -ne 0 ];then
        return "$ret"
    fi 

    LOG_INFO "Success sending $src to $ip."
    
}

getFileFromRemote()
{
    local ip="$1"
    local pwd="$2"
    local src="$3"
    local dest="$4"

    LOG_INFO "Start getting $src from $ip..."
    $SCRIPTS_DIR/get.exp "$ip" "$pwd" "$src" "$dest" > /dev/null 2>&1
    ret="$?"

    if [ "$ret" -ne 0 ];then
        return "$ret"
    fi

    LOG_INFO "Success getting $src from $ip."

}

execCmdOnRemote()
{
    local ip="$1"
    local pwd="$2"
    local cmd="$3"

    $SCRIPTS_DIR/cmd_remote.exp "$ip" "$pwd" "$cmd" > /dev/null 2>&1
    ret="$?"

    if [ "$ret" -ne 0 ];then
        return "$ret"
    fi
}

execCmdOnRemoteWithOutput()
{
    local ip="$1"
    local pwd="$2"
    local cmd="$3"

    $SCRIPTS_DIR/cmd_remote.exp "$ip" "$pwd" "$cmd" 
    ret="$?"

    if [ "$ret" -ne 0 ];then
        return "$ret"
    fi
}

getValueFromJson()
{
    local key="$1"
    local json_file="$2"

    local value=$(jq "$key" "$json_file"  | sed 's/"//g')

    if [ "$value" != "null" ];then
        echo "$value"
    fi
}

pwdCheck()
{
    local ip="$1"
    local pwd="$2"

    $SCRIPTS_DIR/ssh.exp "$ip" "$pwd" > /dev/null 2>&1
    ret="$?"

    return $ret

}

jsonFileCheck()
{
    local json_file="$1"

    jq . "$json_file" > /dev/null 2>&1
    ret="$?"
    if [ "$ret" -ne 0 ];then
        return $ret
    fi
}
