#!/bin/bash
# shadowsocks/SS一键安装脚本,适用于centos7+
# Author: eureka<t4nya7@outlook.com>
# Since: 2023/2/9
main() {
  color_print "$BLUE" "[1] 一键安装SS"
  color_print "$BLUE" "[2] 修改SS配置"
  color_print "$BLUE" "[3] 重启SS服务"
  color_print "$BLUE" "[4] 查看SS状态"
  color_print "$BLUE" "请选择:"
  read -r select
  case "$select" in
  1)
    pre_install
    input_config
    open_port "$PORT"
    systemctl daemon-reload
    systemctl start $NAME
    systemctl enable $NAME
    ehco_link
    ;;
  2)
    input_config
    open_port "$PORT"
    systemctl daemon-reload
    systemctl restart $NAME
    ehco_link
    ;;
  3)
    systemctl restart $NAME
    ;;
  4)
    systemctl status $NAME
    ;;
  *)
    color_print "$RED" "请输入正确的选择"
    ;;
  esac
}

# color
RED="\033[91m"    # Error message
GREEN="\033[92m"  # Success message
BLUE="\033[96m"   # Info message
PLAIN='\033[0m'
# path
CONFIG_FILE="/etc/shadowsocks.json"
SERVICE_FILE="/etc/systemd/system/shadowsocks.service"
NAME="shadowsocks"

color_print() {
  echo -e "${1}${*:2}${PLAIN}"
}

pre_install() {
  color_print "$BLUE" "Install Dependencies..."
  if [ ! "$(command -v curl)" ]; then
    yum install -y curl
  fi
  if [ ! "$(command -v gcc)" ]; then
    yum install -y gcc-c++
  fi
  # Install rust
  color_print "$BLUE" "安装rust，请按照提示选择安装方式"
  curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y
  # Install shadowsock
  color_print "$BLUE" "安装SS"
  "$HOME"/.cargo/bin/cargo install shadowsocks-rust
}

input_config() {
  color_print "$BLUE" "请选择SS的端口号[1-65535]:"
  read -r PORT
  color_print "$GREEN" "使用 ${PORT} 端口"

  color_print "$BLUE" "请选择SS的加密方式（默认chacha20-ietf-poly1305）:"
  options=("plain" "aes-256-gcm" "aes-192-gcm" "aes-128-gcm" "chacha20-ietf-poly1305")
  color_print "$BLUE" "[1] ${options[0]}"
  color_print "$BLUE" "[2] ${options[1]}"
  color_print "$BLUE" "[3] ${options[2]}"
  color_print "$BLUE" "[4] ${options[3]}"
  color_print "$BLUE" "[5] ${options[4]}"
  read -r choice
  METHOD=${options[choice - 1]}
  color_print "$GREEN" "使用${METHOD}加密"

  color_print "$BLUE" "请设置SS的密码（默认随机生成）:"
  read -r PASSWORD
  [[ -z "$PASSWORD" ]] && PASSWORD=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  color_print "$GREEN" "${PASSWORD}"
  gen_config
  if [ ! -f "$SERVICE_FILE" ]; then
    gen_service
  fi
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
  color_print "$BLUE" "开放${1}端口..."
  firewall-cmd --zone=public --add-port="${1}"/tcp --permanent
  firewall-cmd --zone=public --add-port="${1}"/udp --permanent
  firewall-cmd --reload
}

ehco_link() {
  color_print "$GREEN" "SS配置完成，配置文件路径：${CONFIG_FILE},服务名：${NAME}"
  IP=$(curl -sL -4 ip.sb)
  link="ss://"$(echo "${METHOD}":"${PASSWORD}"@"${IP}":"${PORT}" | base64 -w 0)
  color_print "$GREEN" "链接：$link"
}

main "$@" || exit 1
