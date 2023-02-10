#!/bin/bash
main(){
  pre_install
  mkdir /root/bin
  tar -xvf "${FILE_NAME}.tar.xz" -C /root/bin
  gen_config
  gen_service
  open_port "$PORT"
  systemctl daemon-reload
  systemctl start $NAME
  systemctl enable $NAME
  gen_link
}

# constant
PORT=8388
METHOD="chacha20-ietf-poly1305"
PASSWORD=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

# path
CONFIG_FILE="/etc/shadowsocks.json"
SERVICE_FILE="/etc/systemd/system/shadowsocks.service"
LINK_FILE="/root/link.txt"
FILE_NAME="/root/ss-rust"
NAME="shadowsocks"

pre_install(){
  TAG=$(wget -qO- -t1 -T2 "https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
  URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${TAG}/shadowsocks-${TAG}.x86_64-unknown-linux-musl.tar.xz"
  wget -O "${FILE_NAME}.tar.xz" "$URL"
}

gen_service() {
  cat >"$SERVICE_FILE" <<-EOF
[Unit]
Description=Shadowsocks Server
After=network.target

[Service]
ExecStart=/root/bin/ssserver -c $CONFIG_FILE

Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF
}

gen_config() {
  cat >"$CONFIG_FILE" <<-EOF
{
  "server":"0.0.0.0",
  "server_port":${PORT},
  "password":"${PASSWORD}",
  "timeout":600,
  "method":"${METHOD}"
}
EOF
}

open_port() {
  firewall-cmd --zone=public --add-port="${1}"/tcp --permanent
  firewall-cmd --zone=public --add-port="${1}"/udp --permanent
  firewall-cmd --reload
}

gen_link(){
  IP=$(curl -sL -4 ip.sb)
  link="ss://"$(echo "${METHOD}":"${PASSWORD}"@"${IP}":"${PORT}" | base64 -w 0)
  cat >"$LINK_FILE" <<-EOF
$link
EOF
}


main "$@" ||exit 1