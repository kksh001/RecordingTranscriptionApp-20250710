#!/bin/bash

# GitHub Token测试脚本

# 测试token文件存在性
test_token_file_exists() {
    if [ ! -f ~/.cursor/mcp.json ]; then
        echo "测试失败: token文件不存在"
        return 1
    fi
    echo "测试通过: token文件存在"
    return 0
}

# 测试token格式
test_token_format() {
    local token=$(jq -r '.GITHUB_PERSONAL_ACCESS_TOKEN // empty' ~/.cursor/mcp.json)
    if [ -z "$token" ]; then
        echo "测试失败: token为空"
        return 1
    fi
    if [[ ! $token =~ ^gh[ps]_[a-zA-Z0-9]{36}$ ]]; then
        echo "测试失败: token格式不正确"
        return 1
    fi
    echo "测试通过: token格式正确"
    return 0
}

# 测试token权限
test_token_permissions() {
    local token=$(jq -r '.GITHUB_PERSONAL_ACCESS_TOKEN // empty' ~/.cursor/mcp.json)
    local response=$(curl -s -H "Authorization: token $token" https://api.github.com/user)
    if [[ $response == *"Bad credentials"* ]]; then
        echo "测试失败: token无效"
        return 1
    fi
    echo "测试通过: token有效"
    return 0
}

# 主函数
main() {
    echo "开始GitHub Token测试..."
    test_token_file_exists || return 1
    test_token_format || return 1
    test_token_permissions || return 1
    echo "所有测试通过"
}

main 