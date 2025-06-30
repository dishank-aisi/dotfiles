alias c='clear'

# github aliases 
alias gc='git commit -m'
alias glog='git log'
alias ga='git add -u'
alias gs='git status'

# venv aliases
alias activate='source $(pwd)/.venv/bin/activate'

# aws aliases
sls(){
  aws s3 ls s3://$AISI_PLATFORM_BUCKET/teams/ru/agents/dishank/$1/
}
scp(){
  aws s3 cp $1 s3://$AISI_PLATFORM_BUCKET/teams/ru/agents/dishank/$2/
}
alias srm='aws s3 rm'

# Function to get git branch info
function parse_git_branch () {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# Function to format directories
function format_directory () {
  local dir="$PWD"

  # If exactly home, show "~"
  if [[ "$dir" == "$HOME" ]]; then
    echo "~"
  # If direct child of home, show "~/child"
  elif [[ "$dir" =~ ^"$HOME"/[^/]+$ ]]; then
    echo "~/${dir#$HOME/}"
  else
    # Count path segments; for /dir or /dir1/dir2 show full path
    local segments=$(echo "$dir" | awk -F/ '{print NF}')
    if [[ $segments -eq 2 || $segments -eq 3 ]]; then
      echo "$dir"
    else
      # Otherwise, show ../parent_dir/current_dir
      local parent_dir=$(basename "$(dirname "$dir")")
      local current_dir=$(basename "$dir")
      echo "../${parent_dir}/${current_dir}"
    fi
  fi
}

# Custom bash prompt: formatted directory + git branch (in red)
export PS1='\[\e[33m\]$(format_directory)\[\e[m\]\[\e[31m\]$(parse_git_branch)\[\e[m\]\[\e[32m\]\$ \[\e[m\]'
