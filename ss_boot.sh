#!/bin/bash
# vps初始化脚本，使用默认参数静默安装shadowsocks。适用于centos7+
# 生成url保存到 ~/link.txt
# Author: eureka<t4nya7@outlook.com>
# Since: 2023/2/10
main(){
  pre_install
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
LINK_FILE="$HOME/link.txt"
NAME="shadowsocks"

pre_install() {
  if [ ! "$(command -v curl)" ]; then
    yum install -y curl
  fi
  if [ ! "$(command -v gcc)" ]; then
    yum install -y gcc-c++
  fi
  # Install rust
  curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y
  # Install shadowsock
  "$HOME"/.cargo/bin/cargo install shadowsocks-rust
}

gen_service() {
  cat >$SERVICE_FILE <<-EOF
[Unit]
Description=Shadowsocks Server
After=network.target

[Service]
ExecStart=$HOME/.cargo/bin/ssserver -c $CONFIG_FILE

Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF
}

gen_config() {
  cat >$CONFIG_FILE <<-EOF
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
