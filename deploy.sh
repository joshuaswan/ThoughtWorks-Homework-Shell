#!/bin/bash

CUR_DIR="$(pwd)"

export SCRIPTS_DIR="$CUR_DIR/scripts"
export FILES_DIR="$CUR_DIR/files"
export LOG_FILE="$CUR_DIR/deploy.log"

. $SCRIPTS_DIR/common.sh

usage()
{
    echo -e "\e[32mUsage:$0 json\e[m"
    exit
}


envCheck()
{
    if [ ! -f "/etc/yum.repos.d/epel.repo" ];then
        yum install -y epel-release > /dev/null 2>&1 || die "epel install failed."
        LOG_INFO 'epel install success.'
    else
        LOG_INFO 'epel has been installed.'
    fi

    if [ ! -f "$LOG_FILE" ]; then
        touch $LOG_FILE
        chmod 600 $LOG_FILE
    fi 

    if ! which expect > /dev/null 2>&1;then
        yum install expect -y > /dev/null 2>&1 || return 1
        LOG_INFO 'expect install success.'
    else
        LOG_INFO "expect has been installed."
    fi

    if ! which jq > /dev/null 2>&1;then
        yum install jq -y > /dev/null 2>&1 || return 1
        LOG_INFO 'jq install success.'
    else
        LOG_INFO "jq has been installed."
    fi

}


main()
{
    if [ $# -eq 0 ];then
        usage
    fi
    
    envCheck || die  'env check failed.'
    LOG_INFO 'evn check ok.'

    chmod +x $SCRIPTS_DIR/*.sh
    chmod +x $SCRIPTS_DIR/*.exp
    
    local json_file="$1"
   
    jsonFileCheck $json_file || die "Json File check failed."
    LOG_INFO "Json File check ok."

    local server_type=(web_server app_server)
 
    for type in ${server_type[@]}; do
        for ((i=0;i<10;i++));do
	    local ip_key=".$type[$i].ip"
	    local ip=$(getValueFromJson $ip_key $json_file)
	    local passwd_key=".$type[$i].password"
	    local password=$(getValueFromJson $passwd_key $json_file)

            if [ "$ip" != "" ];then
                pwdCheck $ip $password
                ret=$?
                if [ $ret -ne 0 ];then
                    die "Password check failed of $type $ip."
                else
                    LOG_INFO "Password check ok of $type $ip."
                    ECHOANDINFO "Start deploying $type $ip..."
                    putFile2Remote $ip $password "$SCRIPTS_DIR" "/tmp" || die "Put scripts dir to $type $ip failed."
                    putFile2Remote $ip $password "$json_file" "/tmp" || die "Put json file to $type $ip failed."
                    putFile2Remote $ip $password "$SCRIPTS_DIR/${type}_deploy.sh" "/tmp" || die "Put ${type}_deploy.sh to $type $ip failed."

                    if [ "$type" == "web_server" ];then
                        putFile2Remote $ip $password "$FILES_DIR/static.zip" "/tmp" || die "Put static files to $type $ip failed."
                    fi

                    if [ "$type" == "app_server" ];then
                        putFile2Remote $ip $password "$FILES_DIR/jdk" "/tmp" || die "Put jdk file to $type $ip failed."
                        putFile2Remote $ip $password "$FILES_DIR/tomcat" "/tmp" || die "Put tomcat file to $type $ip failed."
                        putFile2Remote $ip $password "$FILES_DIR/project.war" "/tmp" || die "Put project war file to $type $ip failed."
                    fi

		    execCmdOnRemoteWithOutput $ip $password "/bin/bash /tmp/${type}_deploy.sh" >> $LOG_FILE 2>&1 
		    ret="$?"
		    if [ $ret -ne 0 ];then
		        die "Deploy $type $ip failed."
		    else
		        ECHOANDINFO "Deploy $type $ip success."
                        echo
		    fi
                fi
            fi  
        done
    done
    echo -e "\e[33mThank you for using this tool to deploy your environment. You can check \"$LOG_FILE\" for more deploy details.\e[m"
}

main "$@"
