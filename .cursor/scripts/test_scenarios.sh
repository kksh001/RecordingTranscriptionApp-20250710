#!/bin/bash

# 测试场景脚本

# 测试GitHub集成基本功能
test_github_integration() {
    echo "测试GitHub集成..."
    
    # 测试token验证
    if [ -f ~/.cursor/scripts/github_token_validator.sh ]; then
        source ~/.cursor/scripts/github_token_validator.sh
        if ! validate_github_token; then
            echo "测试失败: GitHub token验证"
            return 1
        fi
    else
        echo "测试失败: 找不到token验证脚本"
        return 1
    fi

    echo "测试通过: GitHub集成"
    return 0
}

# 测试Git操作钩子
test_git_operations() {
    echo "测试Git操作钩子..."
    
    local operations=("push" "pull" "fetch" "clone")
    for op in "${operations[@]}"; do
        if [ -f ~/.cursor/scripts/git_operations_hook.sh ]; then
            if ! bash ~/.cursor/scripts/git_operations_hook.sh "$op"; then
                echo "测试失败: Git $op 操作"
                return 1
            fi
        else
            echo "测试失败: 找不到Git操作钩子脚本"
            return 1
        fi
    done

    echo "测试通过: Git操作钩子"
    return 0
}

# 测试环境变量加载
test_env_loading() {
    echo "测试环境变量加载..."
    
    if [ -f ~/.cursor/scripts/load_github_env.sh ]; then
        source ~/.cursor/scripts/load_github_env.sh
        if [ -z "$GITHUB_TOKEN" ]; then
            echo "测试失败: GitHub token环境变量未设置"
            return 1
        fi
    else
        echo "测试失败: 找不到环境变量加载脚本"
        return 1
    fi

    echo "测试通过: 环境变量加载"
    return 0
}

# 主函数
main() {
    echo "开始运行测试场景..."
    test_github_integration || return 1
    test_git_operations || return 1
    test_env_loading || return 1
    echo "所有测试场景通过"
}

main 