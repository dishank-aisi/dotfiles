#!/bin/bash

#clone the branch
echo "---Cloning the repo---"
git clone -b red-team https://github.com/UKGovernmentBEIS/control-arena.git --recurse-submodules
cd control-arena

# uv install everything

echo "---running uv sync...----"
uv sync --dev --all-extras --group aisi-internal


# install kind
echo "-----installing kind-----"
sudo apt --assume-yes install golang-go
go install sigs.k8s.io/kind@v0.27.0

echo "export PATH=~/go/bin:$PATH" >> ~/.bashrc
source ~/.bashrc

# make-setup the k8-settings
echo "-----Make setup for the k8 cluster-----"
cd control_arena/settings/k8s_infra_sabotage_simple
make setup
cd ../../..


echo "------SETUP FINSIHED-------"


