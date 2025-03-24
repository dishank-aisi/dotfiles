#!/bin/bash

#clone the branch
echo "---Cloning the repo---"
git clone https://github.com/UKGovernmentBEIS/control-arena.git --recurse-submodules
cd control-arena

# uv install everything
echo "---running uv sync...----"
uv sync --dev --all-extras

# install kind
echo "-----installing kind-----"

# Set inotify limits and ulimit --> Without this kind causes problem
sudo sh -c 'echo "fs.inotify.max_user_watches=1048576" >> /etc/sysctl.conf'
sudo sh -c 'echo "fs.inotify.max_user_instances=1024" >> /etc/sysctl.conf'
sudo sysctl -p
ulimit -n 1048576
sudo sh -c 'echo "*\tsoft\tnofile\t1048576
*\thard\tnofile\t1048576" >> /etc/security/limits.conf'

sudo apt --assume-yes install golang-go
go install sigs.k8s.io/kind@v0.27.0

echo "export PATH=~/go/bin:$PATH" >> ~/.bashrc
source ~/.bashrc

# make-setup the k8-settings
# echo "-----Make setup for the k8 cluster-----"
# cd control_arena/settings/k8s_infra_sabotage_simple
# make setup
# cd ../../..

# mount the s3 bucket
sudo apt install -y s3fs
mkdir logs
s3fs aisi-data-eu-west-2-prod:/teams/ru/agents/dishank/control-arena/ ~/control-arena/logs -o iam_role=auto -o url=https://s3.eu-west-2.amazonaws.com -o endpoint=eu-west-2 -o use_path_request_style -o compat_dir

echo "------SETUP FINSIHED-------"