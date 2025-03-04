#!/bin/bash

cat << 'EOF' >> $HOME/.bashrc
alias c='clear'

# github aliases 
alias gc='git commit'
alias glog='git log'
alias ga='git add'
alias gs='git status'


#venv aliases
alias activate='source $(pwd)/.venv/bin/activate'

# setting up the shell prompt
parse_git_branch() {
  git_branch=$(git symbolic-ref --short -q HEAD 2>/dev/null)
  if [ -n "$git_branch" ]; then
    git_status=$(git status --porcelain 2>/dev/null)
    if [ -n "$git_status" ]; then
      if echo "$git_status" | grep -q "^??"; then
        git_color="\[\033[0;31m\]" # red for untracked files
      else
        git_color="\[\033[0;32m\]" # green for changes
      fi
    else
      git_color="\[\033[0;36m\]" # cyan for clean
    fi
    echo " $git_color($git_branch)\[\033[0m\]"
  fi
}

# Set the prompt
export PS1='\[\033[0;33m\]\w\[\033[0m\]$(parse_git_branch)\[\033[0;32m\] \$\[\033[0m\] '


EOF
