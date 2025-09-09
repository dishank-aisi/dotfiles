# This file to be used for AISI VM setting to be passed at setup script

# cloning the dotfiles repo
git clone git@github.com:dishank-aisi/dotfiles.git

# setting up the bash
cat dotfiles/aliases.sh >> $HOME/.bashrc
cat dotfiles/env_vars.sh >> $HOME/.bashrc

source $HOME/.bashrc

# setting up claude code
sudo npm install -g @anthropic-ai/claude-code
uv tool install git+ssh://git@github.com/AI-Safety-Institute/claudeup.git

#tmux set up
echo "set -g mouse on" >> ~/.tmux.conf


# installing s3fs to mount buckets
sudo apt install -y s3fs

# setting up the sangbagging propensity
source dotfiles/sandbag-propensity.sh

# setting up the instrinsic 
source dotfiles/intrinsic.sh

# setting up the eval_awareness
source dotfiles/eval-awareness.sh