#!/bin/bash

#clone the branch
echo "---Cloning the repo---"
git clone git@github.com:AI-Safety-Institute/si-hi-intrinsic.git
cd si-hi-intrinsic

# Installing everything
echo "---running uv sync...----"
python -m venv .venv
activate
pip install -e .

# mount the s3 bucket
sudo apt install -y s3fs
mkdir logs
s3fs aisi-data-eu-west-2-prod:/teams/ru/cast-si/intrinsic/dishank/ ./logs -o iam_role=auto -o url=https://s3.eu-west-2.amazonaws.com -o endpoint=eu-west-2 -o use_path_request_style -o compat_dir

touch ~/intrinsic_setup.txt