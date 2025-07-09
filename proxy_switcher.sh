#!/bin/bash

# 代理服务器列表 - 可扩展至更多
PROXY_LIST=(
    "socks5://user1:pass2@proxy-server2.example.com:8888"
    "socks5://user2:pass2@proxy-server2.example.com:8888"
    "socks5://user3:pass3@proxy-server3.example.com:8888"
)

# 代理配置文件
CONFIG_FILE="$HOME/.proxy_config"

# 日志文件
LOG_FILE="$HOME/proxy_switch.log"

# 创建配置文件（如果不存在）
if [ ! -f "$CONFIG_FILE" ]; then
    echo "0" > "$CONFIG_FILE"  # 默认使用第一个代理
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 初始化代理配置文件，使用代理0: ${PROXY_LIST[0]}" >> "$LOG_FILE"
fi

# 记录日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 设置代理函数
set_proxy() {
    local index=$1
    export http_proxy="${PROXY_LIST[$index]}"
    export https_proxy="${PROXY_LIST[$index]}"
    echo "$index" > "$CONFIG_FILE"
    echo "已切换到代理[$index]: ${PROXY_LIST[$index]}"
    log "切换到代理[$index]: ${PROXY_LIST[$index]}"
}

# 取消代理函数
unset_proxy() {
    unset http_proxy https_proxy
    echo "代理已取消"
    log "代理已取消"
}

# 显示当前代理
show_current() {
    local index=$(cat "$CONFIG_FILE")
    echo "当前代理: [$index] ${PROXY_LIST[$index]}"
}

# 显示所有代理
show_all() {
    echo "可用代理列表:"
    for i in "${!PROXY_LIST[@]}"; do
        echo "[$i] ${PROXY_LIST[$i]}"
    done
}

# 自动切换代理（基于日期）
auto_switch() {
    local today=$(date +%-d)  # 获取当天日期（1-31）
    local index=$((today % ${#PROXY_LIST[@]}))  # 使用日期模代理数量作为索引
    
    # 检查是否需要切换
    current_index=$(cat "$CONFIG_FILE")
    if [ "$current_index" -ne "$index" ]; then
        set_proxy "$index"
    else
        echo "今天已经使用代理[$index]，无需切换"
        log "检查代理: 今天已经使用代理[$index]，无需切换"
    fi
}

# 根据参数执行不同操作
case "$1" in
    auto)
        auto_switch
        ;;
    manual)
        show_all
        read -p "请输入要使用的代理编号 [0-${#PROXY_LIST[@]}-1]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -lt "${#PROXY_LIST[@]}" ]; then
            set_proxy "$choice"
        else
            echo "无效的选择"
        fi
        ;;
    current)
        show_current
        ;;
    list)
        show_all
        ;;
    unset)
        unset_proxy
        ;;
    *)
        echo "代理管理脚本 - 支持自动和手动切换多个代理服务器"
        echo "用法: $0 [命令]"
        echo "可用命令:"
        echo "  auto    - 基于日期自动切换代理"
        echo "  manual  - 手动选择代理"
        echo "  current - 显示当前使用的代理"
        echo "  list    - 列出所有可用代理"
        echo "  unset   - 取消代理设置"
        ;;
esac
