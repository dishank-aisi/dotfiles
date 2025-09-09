#!/bin/bash

#clone the branch
echo "---Cloning the repo---"
git clone git@github.com:AI-Safety-Institute/sandbag-propensity.git --recurse-submodules
cd sandbag-propensity

# Installing everything
# uv install everything
echo "---running uv sync...----"
uv sync --dev --all-extras
uv pip install "git+ssh://git@github.com/AI-Safety-Institute/aisi-inspect-tools"

# mount the s3 bucket
mkdir logs
s3fs aisi-data-eu-west-2-prod:/teams/cast/sandbagging/propensity ~/sandbag-propensity/logs -o iam_role=auto -o url=https://s3.eu-west-2.amazonaws.com -o endpoint=eu-west-2 -o use_path_request_style -o compat_dir

touch ~/sangbagging_setup.txt