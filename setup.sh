# clone dotfiles repo
git clone https://dishank-b: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@github.com/dishank-b/dotfiles.git
cd dotfiles

cat aliases.sh >> $HOME/.bashrc
source $HOME/.bashrc

cd ..

source dotfiles/control.sh