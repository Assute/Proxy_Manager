#!/bin/bash

# 代理配置文件路径
PROXY_CONFIG="$HOME/.proxy_config"

# 定义10个不同的代理服务器
PROXY_LIST=(
    "socks5://user1:pass2@proxy-server2.example.com:8888"
    "socks5://user2:pass2@proxy-server2.example.com:8888"
    "socks5://user3:pass3@proxy-server3.example.com:8888"
)

# 根据日期选择代理（确保每天使用同一个代理）
select_daily_proxy() {
    local day_of_year=$(date +%j)  # 获取当年的第几天 (1-366)
    local proxy_index=$(( (day_of_year % ${#PROXY_LIST[@]}) ))
    echo "${PROXY_LIST[$proxy_index]}"
}

# 应用代理配置到当前会话
apply_proxy() {
    local proxy=$(select_daily_proxy)
    export http_proxy="$proxy"
    export https_proxy="$proxy"
    echo "已设置代理: $proxy"
    
    # 写入环境变量文件，使后续终端会话生效
    echo "# 自动生成的代理配置 - $(date)" > "$PROXY_CONFIG"
    echo "export http_proxy=\"$proxy\"" >> "$PROXY_CONFIG"
    echo "export https_proxy=\"$proxy\"" >> "$PROXY_CONFIG"
    
    # 确保bashrc加载此配置
    if ! grep -q "$PROXY_CONFIG" "$HOME/.bashrc"; then
        echo "source $PROXY_CONFIG" >> "$HOME/.bashrc"
    fi
}

# 设置每日定时切换任务
setup_cronjob() {
    local cron_entry="0 0 * * * $(realpath "$0") apply"
    
    # 检查cron任务是否已存在
    if ! crontab -l 2>/dev/null | grep -q "$(basename "$0") apply"; then
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        echo "已设置Crontab任务：每天00:00自动切换代理"
    else
        echo "Crontab任务已存在，无需重复设置"
    fi
}

# 测试代理连接
test_proxy() {
    echo "正在测试代理连接..."
    curl -s https://ipinfo.io | grep -E 'ip|country' || echo "代理测试失败"
}

# 显示当前使用的代理
show_current_proxy() {
    if [ -f "$PROXY_CONFIG" ]; then
        cat "$PROXY_CONFIG"
    else
        echo "未找到代理配置文件"
    fi
}

# 主函数
main() {
    case "$1" in
        apply)
            apply_proxy
            test_proxy
            ;;
        cron)
            setup_cronjob
            ;;
        show)
            show_current_proxy
            ;;
        *)
            echo "用法: $0 [apply|cron|show]"
            echo "  apply - 应用今日代理并测试"
            echo "  cron  - 设置每日自动切换任务"
            echo "  show  - 显示当前使用的代理"
            ;;
    esac
}

main "$@"
