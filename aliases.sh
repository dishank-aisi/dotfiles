#!/bin/bash

cat << 'EOF' >> $HOME/.bashrc
alias c='clear'

# github aliases 
alias gc='git commit'
alias glog='git log'
alias ga='git add -u'
alias gs='git status'


#venv aliases
alias activate='source $(pwd)/.venv/bin/activate'

# Custom bash Prompt
# Function to get git branch info without extra spaces
function parse_git_branch () {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# Set the prompt to include git branch information in red without leading or trailing space
export PS1='\[\e[33m\]\w\[\e[m\]\[\e[31m\]$(parse_git_branch)\[\e[m\]\[\e[32m\]\$ \[\e[m\]'

EOF
