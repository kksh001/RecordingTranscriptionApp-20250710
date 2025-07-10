#!/bin/bash

# Token过期测试脚本

# 模拟不同的token过期场景
test_expiry_scenarios() {
    local token_file=~/.cursor/mcp.json
    local rules_file=~/.cursor/rules/github/token_expiry_rules.json
    
    if [ ! -f "$token_file" ] || [ ! -f "$rules_file" ]; then
        echo "错误: 缺少必要的配置文件"
        return 1
    fi

    # 读取配置
    local warning_days=$(jq -r '.warning_days // 30' "$rules_file")
    local critical_days=$(jq -r '.critical_days // 7' "$rules_file")

    # 测试场景
    echo "测试正常token..."
    test_token_status "valid" 60

    echo -e "\n测试即将过期token..."
    test_token_status "warning" "$warning_days"

    echo -e "\n测试临界token..."
    test_token_status "critical" "$critical_days"

    echo -e "\n测试已过期token..."
    test_token_status "expired" 0
}

# 测试不同状态的token
test_token_status() {
    local status=$1
    local days=$2

    case "$status" in
        "valid")
            echo "Token状态: 有效"
            echo "剩余天数: $days"
            ;;
        "warning")
            echo "Token状态: 警告"
            echo "剩余天数: $days"
            echo "警告: Token将在 $days 天后过期"
            ;;
        "critical")
            echo "Token状态: 临界"
            echo "剩余天数: $days"
            echo "警告: Token即将过期，请尽快更新"
            ;;
        "expired")
            echo "Token状态: 已过期"
            echo "剩余天数: $days"
            echo "错误: Token已过期，请立即更新"
            ;;
    esac
}

# 测试过期通知
test_expiry_notification() {
    local rules_file=~/.cursor/rules/github/token_expiry_rules.json
    
    if [ -f "$rules_file" ]; then
        if [ "$(jq -r '.notification.enabled' "$rules_file")" == "true" ]; then
            local methods=$(jq -r '.notification.methods[]' "$rules_file")
            for method in $methods; do
                echo "使用 $method 发送过期通知"
            done
        else
            echo "通知功能已禁用"
        fi
    else
        echo "警告: 找不到通知配置"
        return 1
    fi
}

# 主函数
main() {
    echo "开始Token过期测试..."
    test_expiry_scenarios
    echo -e "\n测试过期通知:"
    test_expiry_notification
    echo "Token过期测试完成"
}

main 