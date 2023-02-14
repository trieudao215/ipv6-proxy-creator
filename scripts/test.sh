#!/bin/sh
random() {
  tr </dev/urandom -dc A-Za-z0-9 | head -c5
  echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
  ip64() {
    echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
  }
  echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}
install_3proxy() {
  echo "installing 3proxy"
  URL="http://103.176.23.225/files/3proxy-3proxy-0.8.6.tar.gz"
  wget -qO- $URL | bsdtar -xvf-
  cd 3proxy-3proxy-0.8.6
  make -f Makefile.Linux
  mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
  cp src/3proxy /usr/local/etc/3proxy/bin/
  cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
  chmod +x /etc/init.d/3proxy
  chkconfig 3proxy on
  cd $WORKDIR
}

gen_3proxy() {
  cat <<EOF
daemon
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
flush
auth none

$(awk -F "/" '{print "auth none\n" \
"proxy -6 -n -a -p" $2 " -i" $1 " -e"$3"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
  cat >proxy.txt <<EOF
$(awk -F "/" '{print "http://" $1 ":" $2}' ${WORKDATA})
EOF
}

upload_proxy() {
  #local PASS=$(random)
  #zip --password $PASS proxy.zip proxy.txt
  #URL=$(curl -s --upload-file proxy.zip https://transfer.sh/proxy.zip)

  #echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
  #echo "Download zip archive from: ${URL}"
  #echo "Password: ${PASS}"
  
  sed -n '1,1000p' proxy.txt
}

install_jq() {
  wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x ./jq
  cp jq /usr/bin
}

upload_2file() {
  #local PASS=$(random)
  #zip --password $PASS proxy.zip proxy.txt
  #JSON=$(curl -F "file=@proxy.zip" https://file.io)
  #URL=$(echo "$JSON" | jq --raw-output '.link')

  #echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
  #echo "Download zip archive from: ${URL}"
  #echo "Password: ${PASS}"
  
  sed -n '1,1000p' proxy.txt
}

gen_data() {
  seq $FIRST_PORT $LAST_PORT | while read port; do
    echo "$IP4/$port/$(gen64 $IP6)"
  done
}

gen_iptables() {
  cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $2 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

gen_ifconfig() {
  cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $3 "/64"}' ${WORKDATA})
EOF
}
echo "installing apps"
yum -y install gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6="2001:df7:c600:10"

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

echo "How many proxy do you want to create? Example 500"
read COUNT

FIRST_PORT=10001
LAST_PORT=$((($FIRST_PORT + $COUNT)-1))

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
chmod +x boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
service 3proxy start
EOF

bash /etc/rc.local

gen_proxy_file_for_user

# upload_proxy

install_jq && upload_2file