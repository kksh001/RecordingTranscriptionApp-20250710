#!/bin/bash

# Git操作钩子脚本

# 检查是否需要token验证
check_operation_needs_token() {
    local operation=$1
    local needs_token=false

    case "$operation" in
        "push"|"pull"|"fetch"|"clone")
            needs_token=true
            ;;
    esac

    echo "$needs_token"
}

# 验证操作权限
validate_operation() {
    local operation=$1
    
    # 加载GitHub环境
    if [ -f ~/.cursor/scripts/load_github_env.sh ]; then
        source ~/.cursor/scripts/load_github_env.sh
    fi

    # 检查是否需要token
    if [ "$(check_operation_needs_token "$operation")" = true ]; then
        if [ -f ~/.cursor/scripts/github_token_validator.sh ]; then
            source ~/.cursor/scripts/github_token_validator.sh
            validate_github_token || return 1
        fi
    fi

    return 0
}

# 主函数
main() {
    local operation=$1
    if [ -z "$operation" ]; then
        echo "错误: 未指定Git操作"
        return 1
    fi

    validate_operation "$operation"
}

main "$@" 