# This file to be used for AISI VM setting to be passed at setup script

# clone dotfiles repo
git clone https://github.com/dishank-aisi/dotfiles.git

cat dotfiles/aliases.sh >> $HOME/.bashrc

source $HOME/.bashrc
source dotfiles/control.sh
