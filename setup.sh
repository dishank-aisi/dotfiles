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

# setting up the control arena
source dotfiles/control.sh