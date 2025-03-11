# clone dotfiles repo
git clone https://github.com/dishank-aisi/dotfiles.git
cd dotfiles

cat aliases.sh >> $HOME/.bashrc
source $HOME/.bashrc

cd ..

source dotfiles/control.sh