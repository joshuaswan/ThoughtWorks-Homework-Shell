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

nfsServerConfig()
{
    # check rpcbind and nfs 

    # create shared directory
    local shared_dir="/opt/nfs/files"
    [ -d "$share_dir" ] || mkdir -p "$shared_dir"
    
    # unzip static files to shared directory
    unzip /tmp/static.zip -d /opt/nfs/files > /dev/null 2>&1

    service rpcbind status > /dev/null 2>&1
    local ret="$?"
    if [ $ret -eq 3 ];then
        service rpcbind start > /dev/null 2>&1 || die "rpcbind start failed."
    fi

    # modify mountd port 
    sed -ri 's/.*MOUNTD_PORT.*/MOUNTD_PORT=892/' /etc/sysconfig/nfs

    service nfs status > /dev/null 2>&1
    local ret="$?"
    if [ "$ret" -eq 3 ];then
        service nfs start > /dev/null 2>&1 || die "nfs start failed."
    else
        service nfs restart > /dev/null 2>&1 || die "nfs start failed."
    fi

    # get app servers ips and write them into the nfs configure file. In the meantime, configure the iptables rules
    local server_type=(app_server)
    for type in ${server_type[@]}; do 
        for ((i=0;i<10;i++));do
            local ip_key=".$type[$i].ip"
            local ip=$(getValueFromJson $ip_key $json_file)

            if [ "$ip" != '' ];then
                grep $ip /etc/exports | grep "$shared_dir" > /dev/null 2>&1 || echo "/opt/nfs/files $ip(rw)" >> /etc/exports
                grep "\-s $ip.*\-\-dport 111" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p tcp -s $ip --dport 111 -j ACCEPT
                grep "\-s $ip.*\-\-dport 875" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p tcp -s $ip --dport 875 -j ACCEPT
                grep "\-s $ip.*\-\-dport 892" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p tcp -s $ip --dport 892 -j ACCEPT
                grep "\-s $ip.*\-\-dport 2049" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p tcp -s $ip --dport 2049 -j ACCEPT
                grep "\-s $ip.*\-\-dport 111" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p udp -s $ip --dport 111 -j ACCEPT
                grep "\-s $ip.*\-\-dport 875" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p udp -s $ip --dport 875 -j ACCEPT
                grep "\-s $ip.*\-\-dport 892" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p udp -s $ip --dport 892 -j ACCEPT
                grep "\-s $ip.*\-\-dport 2049" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p udp -s $ip --dport 2049 -j ACCEPT
                iptables-save > /etc/sysconfig/iptables
            fi
        done
        iptables-save > /etc/sysconfig/iptables
        exportfs -rv > /dev/null 2>&1
    done
}


nginxInstall()
{
    if ! rpm -q nginx > /dev/null 2>&1;then
        yum install -y nginx > /dev/null 2>&1 || die 'nginx install failed.'
        LOG_INFO 'nginx install success.'
    else
        LOG_INFO 'nginx has been installed.'
    fi
}

nginxConfig()
{
    local servers=''
    local server_type=(app_server)
    for type in ${server_type[@]}; do
        for ((i=0;i<10;i++));do
            local ip_key=".$type[$i].ip"
            local ip=$(getValueFromJson $ip_key $json_file)

            if [ "$ip" != '' ];then
                servers+="server $ip:8080;\n"
            fi
        done
    done
    servers=$(echo -e $servers)

    cat > /etc/nginx/conf.d/app_server.conf <<eof
upstream  appserver {
$servers
}

server {
    listen    8080;
    location / {
    proxy_pass http://appserver;
    proxy_set_header   Host             \$host;
    proxy_set_header   X-Real-IP        \$remote_addr;
    proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
   }
}

eof

nginx -s reload > /dev/null 2>&1

}
removeDeployFiles()
{
    rm -rf /tmp/scripts
    rm -f /tmp/hosts.json
    rm -f /tmp/*deploy.sh
    rm -f /tmp/static.zip
}

iptablesConfig()
{
    grep "\-\-dport 80" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT 
    grep "\-\-dport 443" /etc/sysconfig/iptables > /dev/null 2>&1 || iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT 
    iptables-save > /etc/sysconfig/iptables
}

main()
{
    envCheck
    saltMinionInstall
    nfsServerConfig
    nginxInstall
    nginxConfig
    iptablesConfig
    removeDeployFiles
}


main "$@"

