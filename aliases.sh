alias c='clear'

# github aliases 
alias gc='git commit'
alias glog='git log'
alias ga='git add'


#venv aliases
alias activate='source $(pwd)/.venv/bin/activate'

# prompt format for bash shell
# Check if the current shell is Bash
if [ -n "$BASH_VERSION" ]; then
    # Function to get Git branch and status
    get_git_info() {
        local branch
        local status
        local staged=""
        local unstaged=""
        local untracked=""

        # Check if the current directory is a Git repository
        if branch=$(git symbolic-ref --short HEAD 2>/dev/null); then
            # Get the status of the repository
            status=$(git status --porcelain 2>/dev/null)

            # Check for staged changes
            if echo "$status" | grep -q "^[MADRC]"; then
                staged="\[\e[32m\]"  # Green color for staged changes
            fi

            # Check for unstaged changes
            if echo "$status" | grep -q "^.[MADRC]"; then
                unstaged="\[\e[31m\]"  # Red color for unstaged changes
            fi

            # Check for untracked files
            if echo "$status" | grep -q "^??"; then
                untracked="\[\e[31m\]"  # Red color for untracked files
            fi

            # Combine the status indicators
            echo " \[\e[36m\]$branch$staged$unstaged$untracked\[\e[0m\]"
        fi
    }

    # Enable prompt substitution
    shopt -s promptvars

    # Set the prompt
    export PS1='\[\e[33m\]\w\[\e[0m\]$(get_git_info) \[\e[32m\]$\[\e[0m\] '
fi
