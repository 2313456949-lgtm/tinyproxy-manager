cat > tinyproxy_manager.sh << 'EOF'
#!/bin/bash
# 颜色定义
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;36m'; PLAIN='\033[0m'
CONF_FILE="/etc/tinyproxy/tinyproxy.conf"

# 权限检查
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：请使用 root 用户运行！${PLAIN}" && exit 1

# 动态获取本机公网 IP
get_server_ip() {
    local ip=$(curl -s -m 5 ifconfig.me || curl -s -m 5 icanhazip.com || echo "[服务器IP]")
    echo "$ip"
}

# 打印客户端指令
print_usage() {
    local ip=$1; local port=$2
    echo -e "------------------------------------------------"
    echo -e "${YELLOW}>>> 客户端 (另一台机器) 使用指令 <<<${PLAIN}"
    echo -e "${GREEN}# 测试命令:${PLAIN} curl -x http://$ip:$port http://ifconfig.me"
    echo -e "${GREEN}# 开启代理:${PLAIN} export http_proxy=http://$ip:$port && export https_proxy=http://$ip:$port"
    echo -e "${GREEN}# 关闭代理:${PLAIN} unset http_proxy https_proxy"
    echo -e "------------------------------------------------"
}

# 配置逻辑
configure_tp() {
    clear
    echo -e "${BLUE}--- Tinyproxy 配置中心 ---${PLAIN}"
    read -p "请输入代理端口 (建议 45450): " port
    [[ -z "$port" ]] && port="8888"
    echo -e "1. 允许所有 IP (默认)\n2. 仅允许特定 IP"
    read -p "选择 [1-2]: " choice
    sed -i "s/^Port .*/Port $port/g" $CONF_FILE
    sed -i 's/^Allow /#Allow /g' $CONF_FILE
    [[ "$choice" == "2" ]] && { read -p "输入客户端IP: " uip; echo "Allow $uip" >> $CONF_FILE; }
    
    # 防火墙
    if command -v ufw >/dev/null 2>&1; then ufw allow $port/tcp && ufw reload; fi
    if command -v firewall-cmd >/dev/null 2>&1; then firewall-cmd --zone=public --add-port=$port/tcp --permanent && firewall-cmd --reload; fi
    
    systemctl restart tinyproxy
    echo -e "${GREEN}✔ 配置已生效！${PLAIN}"
    print_usage $(get_server_ip) $port
}

# 安装逻辑
install_tp() {
    echo -e "${YELLOW}正在安装...${PLAIN}"
    if [ -f /etc/redhat-release ]; then yum install -y epel-release && yum install -y tinyproxy
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then apt-get update && apt-get install -y tinyproxy
    else echo "系统不支持"; exit 1; fi
    configure_tp
}

# 菜单
menu() {
    clear
    echo -e "${BLUE}Tinyproxy 交互管理脚本${PLAIN}"
    echo -e "1. 安装并配置\n2. 修改端口/IP权限\n3. 查看客户端指令\n4. 重启服务\n5. 卸载\n0. 退出"
    read -p "请选择: " n
    case "$n" in
        1) install_tp ;;
        2) configure_tp ;;
        3) print_usage $(get_server_ip) $(grep "^Port" $CONF_FILE | awk '{print $2}') ;;
        4) systemctl restart tinyproxy && echo "已重启" ;;
        5) systemctl stop tinyproxy; if [ -f /etc/redhat-release ]; then yum remove -y tinyproxy; else apt-get purge -y tinyproxy; fi; rm -rf /etc/tinyproxy; echo "已卸载" ;;
        0) exit 0 ;;
        *) menu ;;
    esac
}
menu
EOF
chmod +x tinyproxy_manager.sh && ./tinyproxy_manager.sh
