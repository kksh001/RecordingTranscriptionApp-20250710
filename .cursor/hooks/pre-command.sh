#!/bin/bash

# Git pre-command hook
if [[ "$1" == "git"* ]]; then
    # 验证GitHub token
    if [ -f ~/.cursor/scripts/github_token_validator.sh ]; then
        source ~/.cursor/scripts/github_token_validator.sh
        validate_github_token || exit 1
    fi
fi

exit 0 