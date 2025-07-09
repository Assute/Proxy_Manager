#!/bin/bash

# 代理配置目录和文件
CONFIG_DIR="$HOME/.proxy_manager"
CONFIG_FILE="$CONFIG_DIR/proxies.conf"
STATE_FILE="$CONFIG_DIR/state.conf"
LOG_FILE="$CONFIG_DIR/proxy_switch.log"
CRON_TIME_FILE="$CONFIG_DIR/cron_time.conf"  # 存储用户设置的定时时间

# 确保配置目录存在
mkdir -p "$CONFIG_DIR"

# 创建配置文件（如果不存在）
if [ ! -f "$CONFIG_FILE" ]; then
    touch "$CONFIG_FILE"
    echo "0" > "$STATE_FILE"  # 默认使用第一个代理
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 初始化代理配置文件" >> "$LOG_FILE"
fi

# 记录日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 加载代理列表
load_proxies() {
    PROXY_LIST=()
    while IFS= read -r line; do
        PROXY_LIST+=("$line")
    done < "$CONFIG_FILE"
}

# 保存代理列表
save_proxies() {
    printf "%s\n" "${PROXY_LIST[@]}" > "$CONFIG_FILE"
}

# 获取当前选中的代理索引
get_current_index() {
    if [ -f "$STATE_FILE" ]; then
        echo $(cat "$STATE_FILE")
    else
        echo "0"
    fi
}

# 设置当前选中的代理索引
set_current_index() {
    echo "$1" > "$STATE_FILE"
}

# 设置代理函数
set_proxy() {
    local index=$1
    if [ -n "${PROXY_LIST[$index]}" ]; then
        export http_proxy="${PROXY_LIST[$index]}"
        export https_proxy="${PROXY_LIST[$index]}"
        set_current_index "$index"
        echo "已切换到代理[$index]: ${PROXY_LIST[$index]}"
        log "切换到代理[$index]: ${PROXY_LIST[$index]}"
    else
        echo "错误: 无效的代理索引"
        log "错误: 无效的代理索引 $index"
    fi
}

# 取消代理函数
unset_proxy() {
    unset http_proxy https_proxy
    echo "代理已取消"
    log "代理已取消"
}

# 显示当前代理
show_current() {
    local index=$(get_current_index)
    if [ -n "${PROXY_LIST[$index]}" ]; then
        echo "当前代理: [$index] ${PROXY_LIST[$index]}"
    else
        echo "当前没有设置有效代理"
    fi
}

# 显示所有代理
show_all() {
    echo "可用代理列表:"
    for i in "${!PROXY_LIST[@]}"; do
        echo "[$i] ${PROXY_LIST[$i]}"
    done
    
    if [ ${#PROXY_LIST[@]} -eq 0 ]; then
        echo "没有配置任何代理服务器"
    fi
}

# 自动切换代理（基于日期）
auto_switch() {
    load_proxies
    local proxy_count=${#PROXY_LIST[@]}
    
    if [ $proxy_count -eq 0 ]; then
        echo "没有配置任何代理服务器，无法自动切换"
        log "错误: 没有配置任何代理服务器"
        return
    fi
    
    local today=$(date +%-d)  # 获取当天日期（去除前导零）
    local index=$((today % proxy_count))  # 使用日期模代理数量作为索引
    
    # 检查是否需要切换
    current_index=$(get_current_index)
    if [ "$current_index" -ne "$index" ]; then
        set_proxy "$index"
    else
        echo "今天已经使用代理[$index]，无需切换"
        log "检查代理: 今天已经使用代理[$index]，无需切换"
    fi
}

# 验证时间格式（HH:MM:SS）
validate_time_format() {
    local time_str="$1"
    if [[ ! "$time_str" =~ ^([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$ ]]; then
        echo "无效的时间格式！请使用HH:MM:SS格式，例如06:00:00"
        return 1
    fi
    return 0
}

# 配置 cron 任务（强制覆盖旧任务）
setup_cron() {
    local script_path=$(realpath "$0")
    
    # 先清除所有已存在的同类型任务（确保只保留最新的）
    if crontab -l 2>/dev/null | grep -qF "$script_path auto"; then
        echo "检测到旧的定时任务，正在清除..."
        (crontab -l 2>/dev/null | grep -vF "$script_path auto") | crontab -
    fi
    
    # 提示用户输入时间（HH:MM:SS格式）
    echo "请设置每日自动切换代理的时间（24小时制，格式为HH:MM:SS，例如06:00:00）"
    read -p "输入时间: " time_input
    
    # 验证时间格式
    if ! validate_time_format "$time_input"; then
        return 1
    fi
    
    # 解析时、分、秒（cron不支持秒级，秒数仅用于显示）
    IFS=':' read -r hour minute second <<< "$time_input"
    
    # 构建 cron 任务（分 时 * * *）
    local cron_entry="$minute $hour * * * source $script_path auto"
    
    # 添加新的 cron 任务
    echo "正在设置每日$time_input自动切换代理的任务..."
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    
    # 保存用户设置的完整时间（含秒）
    echo "$time_input" > "$CRON_TIME_FILE"
    
    echo "✅ 定时任务已更新，每天$time_input自动切换代理"
    log "Cron 任务已设置: $cron_entry"
    
    # 显示当前生效的任务
    echo -e "\n当前生效的自动切换任务:"
    crontab -l 2>/dev/null | grep -F "$script_path auto"
}

# 移除 cron 任务
remove_cron() {
    local script_path=$(realpath "$0")
    
    echo "正在移除所有自动切换代理的任务..."
    
    # 清除所有相关任务
    if crontab -l 2>/dev/null | grep -qF "$script_path auto"; then
        (crontab -l 2>/dev/null | grep -vF "$script_path auto") | crontab -
        echo "✅ 所有代理自动切换任务已移除"
        log "Cron 任务已移除: 所有与 $script_path 相关的自动切换任务"
    else
        echo "❌ 没有检测到代理自动切换任务"
    fi
    
    # 删除时间记录文件
    rm -f "$CRON_TIME_FILE"
    
    # 显示当前的 crontab
    echo -e "\n当前的定时任务列表:"
    crontab -l 2>/dev/null || echo "无任何定时任务"
}

# 测试代理连接
test_proxy() {
    echo "正在测试当前代理连接..."
    local test_url="https://www.google.com"
    
    # 使用 curl 测试连接，设置超时时间为 10 秒
    if curl --connect-timeout 10 -s --head "$test_url" | grep -q "200 OK"; then
        echo "代理连接成功"
        return 0
    else
        echo "代理连接失败"
        return 1
    fi
}

# 测试所有代理连接
test_all_proxies() {
    load_proxies
    echo "正在测试所有代理服务器的连接..."
    
    for i in "${!PROXY_LIST[@]}"; do
        echo -e "\n测试代理[$i]: ${PROXY_LIST[$i]}"
        
        # 临时设置当前代理进行测试
        export http_proxy="${PROXY_LIST[$i]}"
        export https_proxy="${PROXY_LIST[$i]}"
        
        # 使用 curl 测试连接，设置超时时间为 5 秒
        if curl --connect-timeout 5 -s --head "https://www.google.com" | grep -q "200 OK"; then
            echo "代理[$i]连接成功"
        else
            echo "代理[$i]连接失败"
        fi
    done
    
    # 恢复原来的代理设置
    current_index=$(get_current_index)
    if [ -n "${PROXY_LIST[$current_index]}" ]; then
        export http_proxy="${PROXY_LIST[$current_index]}"
        export https_proxy="${PROXY_LIST[$current_index]}"
    else
        unset http_proxy https_proxy
    fi
}

# 显示当前IP
show_current_ip() {
    echo "正在查询当前公网IP地址..."
    
    if command -v curl &> /dev/null; then
        # 尝试使用代理（如果已设置）查询IP
        local ip_info=$(curl -s https://ipinfo.io)
        
        if [ $? -eq 0 ]; then
            echo "当前公网IP信息:"
            echo "$ip_info"
        else
            # 如果失败，尝试不使用代理查询
            echo "使用代理查询失败，尝试直接连接..."
            local ip_info=$(HTTPS_PROXY= HTTP_PROXY= curl -s https://ipinfo.io)
            
            if [ $? -eq 0 ]; then
                echo "当前公网IP信息（未使用代理）:"
                echo "$ip_info"
                echo "提示: 代理可能未正确配置或不可用"
            else
                echo "无法查询IP地址，请检查网络连接"
            fi
        fi
    else
        echo "错误: 需要安装 curl 才能查询IP地址"
    fi
}

# 添加新代理
add_proxy() {
    echo "=== 添加新代理服务器 ==="
    
    # 获取代理类型
    echo "选择代理类型:"
    echo "1. HTTP"
    echo "2. HTTPS"
    echo "3. SOCKS4"
    echo "4. SOCKS5"
    read -p "输入代理类型 [1-4]: " proxy_type
    
    case $proxy_type in
        1) proxy_prefix="http://" ;;
        2) proxy_prefix="https://" ;;
        3) proxy_prefix="socks4://" ;;
        4) proxy_prefix="socks5://" ;;
        *) 
            echo "无效的选择，使用默认的 SOCKS5"
            proxy_prefix="socks5://" 
            ;;
    esac
    
    # 获取代理服务器地址
    read -p "输入代理服务器 IP 地址: " proxy_ip
    read -p "输入代理服务器端口: " proxy_port
    
    # 询问是否需要用户名和密码
    read -p "是否需要用户名和密码? [y/N]: " use_auth
    
    if [[ "$use_auth" =~ ^[Yy]$ ]]; then
        read -p "输入用户名: " proxy_user
        read -s -p "输入密码: " proxy_pass
        echo
        
        # 构建带认证的代理URL
        proxy_url="${proxy_prefix}${proxy_user}:${proxy_pass}@${proxy_ip}:${proxy_port}"
    else
        # 构建不带认证的代理URL
        proxy_url="${proxy_prefix}${proxy_ip}:${proxy_port}"
    fi
    
    # 添加到代理列表
    load_proxies
    PROXY_LIST+=("$proxy_url")
    save_proxies
    
    echo "已添加代理: $proxy_url"
    log "添加新代理: $proxy_url"
}

# 删除代理
delete_proxy() {
    echo "=== 删除代理服务器 ==="
    load_proxies
    
    if [ ${#PROXY_LIST[@]} -eq 0 ]; then
        echo "没有配置任何代理服务器"
        return
    fi
    
    show_all
    
    read -p "输入要删除的代理编号 [0-$(( ${#PROXY_LIST[@]} - 1 ))]: " index
    
    if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -lt "${#PROXY_LIST[@]}" ]; then
        echo "即将删除代理: ${PROXY_LIST[$index]}"
        read -p "确定要删除吗? [y/N]: " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # 删除指定索引的代理
            unset PROXY_LIST[$index]
            # 重建数组索引
            PROXY_LIST=("${PROXY_LIST[@]}")
            save_proxies
            
            # 如果删除的是当前使用的代理，重置当前索引
            current_index=$(get_current_index)
            if [ "$index" -eq "$current_index" ] && [ ${#PROXY_LIST[@]} -gt 0 ]; then
                set_current_index "0"
                set_proxy "0"
            fi
            
            echo "已删除代理"
            log "删除代理: $index"
        else
            echo "取消删除"
        fi
    else
        echo "无效的选择"
    fi
}

# 显示菜单
show_menu() {
    clear
    echo "====================================="
    echo "        代理服务器管理菜单"
    echo "====================================="
    echo "1. 添加代理"
    echo "2. 删除代理"
    echo "3. 取消代理"
    echo "4. 手动设置代理"
    echo "5. 列出所有代理"
    echo "6. 检测可用代理"
    echo "7. 检测当前代理IP"
    echo "8. 设置每日自动切换代理定时任务"
    echo "9. 移除每日自动切换代理定时任务"
    echo "0. 退出"
    echo "-------------------------------------"
}

# 主程序
while true; do
    show_menu
    read -p "请输入你的选择 [0-9]: " choice
    echo

    case $choice in
        1)
            add_proxy
            ;;
        2)
            delete_proxy
            ;;
        3)
            unset_proxy
            ;;
        4)
            load_proxies
            show_all
            if [ ${#PROXY_LIST[@]} -gt 0 ]; then
                read -p "请输入要使用的代理编号 [0-$(( ${#PROXY_LIST[@]} - 1 ))]: " proxy_index
                if [[ "$proxy_index" =~ ^[0-9]+$ ]] && [ "$proxy_index" -lt "${#PROXY_LIST[@]}" ]; then
                    set_proxy "$proxy_index"
                else
                    echo "无效的选择"
                fi
            fi
            ;;
        5)
            load_proxies
            show_all
            ;;
        6)
            test_all_proxies
            ;;
        7)
            show_current_ip
            ;;
        8)
            setup_cron
            ;;
        9)
            remove_cron
            ;;
        0)
            echo "退出菜单..."
            break
            ;;
        *)
            echo "无效的选择，请输入 0-9 之间的数字"
            ;;
    esac
    
    echo
    read -p "按 Enter 键继续..."
done
