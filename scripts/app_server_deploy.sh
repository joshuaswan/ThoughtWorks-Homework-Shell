#!/bin/bash


cd /tmp

CUR_DIR="$(pwd)"
. $CUR_DIR/scripts/common.sh
json_file="$CUR_DIR/hosts.json"

envCheck()
{
    if [ ! -f "/etc/yum.repos.d/epel.repo" ];then
        yum install -y epel-release > /dev/null 2>&1 || die "epel install failed."
        LOG_INFO 'epel install success.'
    else
        LOG_INFO 'epel has been installed.'
    fi

    if ! which jq > /dev/null 2>&1;then
        yum install jq -y > /dev/null 2>&1 || return 1
        LOG_INFO 'jq install success.'
    else
        LOG_INFO "jq has been installed."
    fi
}

saltMinionInstall()
{
    if ! rpm -q salt-minion > /dev/null 2>&1;then
        yum install -y salt-minion > /dev/null 2>&1 || die "salt-minion install failed."
        LOG_INFO "salt-minion install success."
    fi
}

nfsClientConfig()
{
    [ -d "/opt/nfs/files" ] || mkdir -p "/opt/nfs/files" 

    # get nfs server ip and mount the shared directory
    local server_type=(web_server)
    for type in ${server_type[@]}; do
        for ((i=0;i<10;i++));do
            local ip_key=".$type[$i].ip"
            local ip=$(getValueFromJson $ip_key $json_file)

            if [ "$ip" != '' ];then
                if ! df -h | grep "$ip" > /dev/null 2>&1;then
                    mount $ip:/opt/nfs/files /opt/nfs/files || die 'mount shared directory failed.'
                else
                    LOG_INFO 'shared directory has been mounted.'
                fi
            fi
        done
    done
}

jdkInstall()
{
    tar xf jdk/jdk-8u111-linux-x64.tar.gz -C /opt
    [ -L "/opt/jdk" ] || ln -s /opt/jdk1.8.0_111 /opt/jdk
    if ! grep JAVA_HOME /etc/profile > /dev/null 2>&1;then
        echo -e "export JAVA_HOME=/opt/jdk\nexport CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar\nexport PATH=\$JAVA_HOME/bin:\$PATH"  >> /etc/profile
    fi
}

tomcatInstall()
{
    tar xf tomcat/apache-tomcat-8.5.9.tar.gz -C /opt
    [ -L "/opt/tomcat" ] || ln -s /opt/apache-tomcat-8.5.9 /opt/tomcat
    
    # copy .war file to webapps directory
    cp -a /tmp/project.war /opt/tomcat/webapps

    #start server
    if ! lsof -i:8080 > /dev/null 2>&1;then
        /opt/tomcat/bin/startup.sh > /dev/null 2>&1
    fi
}

removeDeployFiles()
{
    rm -rf /tmp/scripts
    rm -f /tmp/hosts.json
    rm -f /tmp/*deploy.sh
    rm -rf /tmp/jdk
    rm -rf /tmp/tomcat
    rm -rf /tmp/project.war
}

iptablesConfig()
{
    grep "\-\-dport 8080" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT      
    iptables-save > /etc/sysconfig/iptables
}

main()
{
    envCheck
    saltMinionInstall
    nfsClientConfig
    jdkInstall
    tomcatInstall    
    iptablesConfig 
    removeDeployFiles
}


main "$@"
