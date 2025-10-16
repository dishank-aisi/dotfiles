#!/bin/bash

touch ~/intrinsic_setup.txt

#clone the branch
echo "---Cloning the repo---" >> ~/intrinsic_setup.txt
git clone git@github.com:AI-Safety-Institute/si-hi-intrinsic.git
cd si-hi-intrinsic

# Installing everything
echo "---running uv sync...----" >> ~/intrinsic_setup.txt
python -m venv .venv
activate
pip install -e .

# mounting s3 bucket
echo "---Mounting the s3 bucket---" >> ~/intrinsic_setup.txt
mkdir logs
s3fs aisi-data-eu-west-2-prod:/teams/ru/cast-si/intrinsic/dishank/ ./logs -o iam_role=auto -o url=https://s3.eu-west-2.amazonaws.com -o endpoint=eu-west-2 -o use_path_request_style -o compat_dir

echo "---Intrinsic project steup complete---" >> ~/intrinsic_setup.txt
