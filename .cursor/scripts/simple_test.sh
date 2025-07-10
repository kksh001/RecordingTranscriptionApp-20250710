#!/bin/bash

# 简单测试脚本

# 检查必要文件
check_required_files() {
    local files=(
        "~/.cursor/mcp.json"
        "~/.cursor/scripts/github_token_validator.sh"
        "~/.cursor/scripts/check_token_expiry.sh"
        "~/.cursor/scripts/load_github_env.sh"
        "~/.cursor/scripts/git_operations_hook.sh"
    )

    for file in "${files[@]}"; do
        if [ ! -f "$(eval echo $file)" ]; then
            echo "错误: 文件不存在: $file"
            return 1
        fi
    done

    return 0
}

# 检查文件权限
check_file_permissions() {
    local config_files=(
        "~/.cursor/mcp.json"
        "~/.cursor/config/github_integration.json"
    )

    for file in "${config_files[@]}"; do
        local expanded_path=$(eval echo $file)
        if [ -f "$expanded_path" ]; then
            if [ "$(stat -f '%OLp' "$expanded_path")" != "600" ]; then
                echo "警告: 文件权限不正确: $file"
                return 1
            fi
        fi
    done

    return 0
}

# 主函数
main() {
    echo "运行简单测试..."
    check_required_files || exit 1
    check_file_permissions || exit 1
    echo "简单测试通过"
}

main 