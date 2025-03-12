# This file to be used for AISI VM setting to be passed at setup script

cat dotfiles/aliases.sh >> $HOME/.bashrc
cat dotfiles/env_vars.sh >> $HOME/.bashrc

source $HOME/.bashrc

# setting up the control_arena
git clone https://github.com/dishank-aisi/dotfiles.git
source dotfiles/control.sh
