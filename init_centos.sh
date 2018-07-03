#!/bin/bash
yum -y install vim chrony salt-minion-2016.3.4 zabbix-agent iptables-services gcc gcc-c++ openssl openssl-devel openssh-clients wget make lrzsz unzip zip xz lsof telnet epel-release vim tree  man

useradd ops -u 2000
usermod ops -aG wheel

#设置变量name接收第一个参数（要创建的用户名），$n表示第n个参数，且=两边不能有空格
name=ops
#设置变量pass接收第二个参数（要为其设置的密码）
pass=PrdQuark@123
#echo语句会输出到控制台，${变量}或者 $变量 表示变量代表的字符串
echo "you are setting username : ${name}"
echo "you are setting password : $pass for ${name}"
#添加用户$name，此处sudo需要设置为无密码，后面将会作出说明
#如果上一个命令正常运行，则输出成功，否则提示失败并以非正常状态退出程序
# $?表示上一个命令的执行状态，-eq表示等于，[ 也是一个命令
# if fi 是成对使用的，后面是前面的倒置，很多这样的用法。
if [ $? -eq 0 ];then
   echo "user ${name} is created successfully!!!"
else
   echo "user ${name} is created failly!!!"
   exit 1
fi
#sudo passwd $name会要求填入密码，下面将$pass作为密码传入
echo $pass | sudo passwd $name --stdin  &>/dev/null
if [ $? -eq 0 ];then
   echo "${name}'s password is set successfully"
else
   echo "${name}'s password is set failly!!!"
fi

mkdir -p /opt/platform/tools
chown -R ops:ops /opt/platform

systemctl enable chronyd
systemctl start chronyd
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp yes

systemctl stop firewalld
systemctl disable firewalld
systemctl enable iptables

cat > /etc/sysconfig/iptables << eof
# sample configuration for iptables service
# you can edit this manually or use system-config-firewall
# please do not ask us to add additional ports/services to this default configuration
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

-A INPUT -s 127.0.0.1/32 -d 127.0.0.1/32 -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
COMMIT
eof

systemctl restart iptables

setenforce 0
sed -ri 's/^(SELINUX=).*/\1disabled/' /etc/selinux/config

cat > /etc/security/limits.d/10-nproc.conf << eof
*         soft       nproc     20480
*         hard       nproc     20480
root      soft       nproc     unlimited
root      hard       nproc     unlimited
*         soft       nofile    1048576
*         hard       nofile    1048576
eof

cat > /etc/sysctl.conf << eof
#开启转发
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1

#端口范围
net.ipv4.ip_local_port_range = 2048 65535
#监听队列长度
net.core.somaxconn = 4096
#网络接口接收数据包的速率比内核处理包的速率快时，允许送到队列的数据包的最大数目
net.core.netdev_max_backlog = 65000
#SYN_RECV状态队列长度
net.ipv4.tcp_max_syn_backlog = 8196
eof

sysctl -p

ip=`ifconfig | grep -1 eth0 | grep inet | awk  '{print $2}'`
hostname=`hostname`
cat >> /etc/hosts << eof
${ip}  ${hostname}
eof
