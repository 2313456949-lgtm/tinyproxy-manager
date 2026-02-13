#!/bin/bash

# ====================================================
# Project: Tinyproxy Manager
# Description: One-click script to install and manage Tinyproxy
# Author: YourName
# GitHub: your-github-link
# ====================================================

# 颜色定义
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;36m'; PLAIN='\033[0m'
CONF_FILE="/etc/tinyproxy/tinyproxy.conf"

# 检查是否为 Root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：请使用 root 用户运行！${PLAIN}"
    exit 1
fi

# 动态获取本机公网 IP
get_server_ip() {
    local ip=$(curl -s -m 5 ifconfig.me || curl -s -m 5 icanhazip.com || echo "[服务器IP]")
    echo "$ip"
}

# 打印客户端指令
print_usage() {
    local ip=$1
    local port=$2
    echo -e "------------------------------------------------"
    echo -e "${YELLOW}>>> 客户端使用指南 <<<${PLAIN}"
    echo -e "${GREEN}# 测试连接:${PLAIN} curl -x http://$ip:$port http://ifconfig.me"
    echo -e "${GREEN}# 设置环境变量:${PLAIN}"
    echo -e "    export http_proxy=http://$ip:$port"
    echo -e "    export https_proxy=http://$ip:$port"
    echo -e "${GREEN}# 取消代理:${PLAIN} unset http_proxy https_proxy"
    echo -e "------------------------------------------------"
}

# 配置逻辑
configure_tp() {
    clear
    echo -e "${BLUE}--- Tinyproxy 配置中心 ---${PLAIN}"
    read -p "请输入代理端口 (默认 8888): " port
    [[ -z "$port" ]] && port="8888"
    
    echo -e "访问控制策略:"
    echo -e "1. 允许所有 IP (不推荐用于公网)"
    echo -e "2. 仅允许特定 IP (安全)"
    read -p "选择 [1-2]: " choice
    
    # 备份原始配置
    cp $CONF_FILE "${CONF_FILE}.bak"
    
    # 修改端口
    sed -i "s/^Port .*/Port $port/g" $CONF_FILE
    # 注释掉所有旧的 Allow 规则
    sed -i 's/^Allow /#Allow /g' $CONF_FILE
    
    if [[ "$choice" == "2" ]]; then
        read -p "请输入允许访问的客户端 IP: " uip
        echo "Allow $uip" >> $CONF_FILE
    fi
    
    # 防火墙自动放行
    if command -v ufw >/dev/null 2>&1; then 
        ufw allow $port/tcp && ufw reload
    elif command -v firewall-cmd >/dev/null 2>&1; then 
        firewall-cmd --zone=public --add-port=$port/tcp --permanent && firewall-cmd --reload
    fi
    
    systemctl restart tinyproxy
    echo -e "${GREEN}✔ 配置已生效！${PLAIN}"
    print_usage $(get_server_ip) $port
}

# 安装逻辑
install_tp() {
    echo -e "${YELLOW}正在识别系统并安装...${PLAIN}"
    if [ -f /etc/redhat-release ]; then
        yum install -y epel-release && yum install -y tinyproxy
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y tinyproxy
    else
        echo -e "${RED}抱歉，暂不支持您的系统。${PLAIN}"
        exit 1
    fi
    configure_tp
}

# 菜单
menu() {
    echo -e "${BLUE}Tinyproxy 交互管理脚本${PLAIN}"
    echo -e "1. 安装并配置"
    echo -e "2. 修改配置 (端口/IP)"
    echo -e "3. 查看使用指令"
    echo -e "4. 重启服务"
    echo -e "5. 卸载 Tinyproxy"
    echo -e "0. 退出"
    read -p "请选择: " n
    case "$n" in
        1) install_tp ;;
        2) configure_tp ;;
        3) 
           current_port=$(grep "^Port" $CONF_FILE | awk '{print $2}')
           print_usage $(get_server_ip) ${current_port:-8888} 
           ;;
        4) systemctl restart tinyproxy && echo "已重启" ;;
        5) 
           read -p "确定要卸载吗？[y/n]: " confirm
           if [[ "$confirm" == "y" ]]; then
               systemctl stop tinyproxy
               [ -f /etc/redhat-release ] && yum remove -y tinyproxy || apt-get purge -y tinyproxy
               rm -rf /etc/tinyproxy
               echo "已彻底卸载"
           fi
           ;;
        0) exit 0 ;;
        *) menu ;;
    esac
}

menu

