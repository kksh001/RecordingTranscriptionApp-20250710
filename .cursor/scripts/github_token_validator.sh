#!/bin/bash

validate_github_token() {
    if [ ! -f ~/.cursor/mcp.json ]; then
        echo "错误: GitHub token配置文件不存在"
        return 1
    fi

    # 检查token是否过期
    if [ -f ~/.cursor/scripts/check_token_expiry.sh ]; then
        source ~/.cursor/scripts/check_token_expiry.sh
        check_token_expiry || return 1
    fi

    return 0
}

# 加载环境变量
if [ -f ~/.cursor/scripts/load_github_env.sh ]; then
    source ~/.cursor/scripts/load_github_env.sh
fi 