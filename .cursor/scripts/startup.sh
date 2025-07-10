#!/bin/bash

# Cursor IDE 项目启动脚本

# 检查必要的配置文件
check_config_files() {
    local required_files=(
        ".cursor/settings.json"
        ".cursor/hooks/pre-command.sh"
        "~/.cursor/mcp.json"
    )

    for file in "${required_files[@]}"; do
        if [ ! -f "$(eval echo $file)" ]; then
            echo "警告: 配置文件不存在: $file"
        fi
    done
}

# 检查并设置正确的文件权限
setup_permissions() {
    # 设置脚本执行权限
    chmod 755 .cursor/hooks/pre-command.sh
    chmod 755 .cursor/scripts/*.sh

    # 设置配置文件权限
    chmod 600 .cursor/settings.json
    chmod 600 .cursor/rules/github/token_expiry_rules.json
}

# 初始化GitHub集成
init_github_integration() {
    if [ -f ~/.cursor/scripts/github_token_validator.sh ]; then
        source ~/.cursor/scripts/github_token_validator.sh
        validate_github_token
    fi
}

# 主函数
main() {
    echo "正在初始化Cursor IDE项目环境..."
    check_config_files
    setup_permissions
    init_github_integration
    echo "初始化完成"
}

main 