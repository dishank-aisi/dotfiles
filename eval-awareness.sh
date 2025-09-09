#!/bin/bash

#clone the branch
echo "---Cloning the repo---"
git clone git@github.com:AI-Safety-Institute/cast-sandbagging.git --recurse-submodules
cd cast-sandbagging/eval_awareness

# Installing everything
# uv install everything
echo "---running uv sync...----"
uv sync --dev --all-extras

# mount the s3 bucket
mkdir logs
s3fs aisi-data-eu-west-2-prod:/teams/cast/sandbagging/eval_awareness/dishank/ ./logs -o iam_role=auto -o url=https://s3.eu-west-2.amazonaws.com -o endpoint=eu-west-2 -o use_path_request_style -o compat_dir

touch ~/eval_awareness.txt