# This file to be used for AISI VM setting to be passed at setup script

cat dotfiles/aliases.sh >> $HOME/.bashrc
cat dotfiles/env_vars.sh >> $HOME/.bashrc

source $HOME/.bashrc

# setting up the control_arena
git clone https://github.com/dishank-aisi/dotfiles.git
source dotfiles/control.sh

s3fs aisi-data-eu-west-2-prod:/teams/ru/agents/dishank/control_arena/ ~/control-arena/lol_logs -o iam_role=auto -o url=https://s3.eu-west-2.amazonaws.com -o endpoint=eu-west-2 -o use_path_request_style -o compat_dir