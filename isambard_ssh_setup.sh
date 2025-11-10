#!/bin/bash

set -euo pipefail

# Configures local macbook ssh config to auth & login to Isambard via an (existing) EC2 dev box

SSH_CONFIG_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_CONFIG_DIR/config"
CONFIG_CLIFTON_FILENAME="config_clifton"
CONFIG_CLIFTON_OVERRIDE_FILENAME="config_clifton_override"
CONFIG_CLIFTON_PATH="$SSH_CONFIG_DIR/$CONFIG_CLIFTON_FILENAME"
CONFIG_CLIFTON_OVERRIDE_PATH="$SSH_CONFIG_DIR/$CONFIG_CLIFTON_OVERRIDE_FILENAME"
AISI_PRIVATE_KEY="aisi_internal"

check_prerequisites() {
    local missing_cmds=()

    for cmd in aisi ssh scp awk sed; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_cmds+=("$cmd")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        echo "Error: Missing required commands: ${missing_cmds[*]}"
        exit 1
    fi
}

# sed in-place editing, compatible with macOS and Linux
sed_inplace() {
    local pattern="$1"
    local file="$2"
    local tmp_file
    tmp_file=$(mktemp)
    sed "$pattern" "$file" > "$tmp_file" && mv "$tmp_file" "$file"
}

# Pick a running dev box to use as a jump host
# If multiple are running, prompt the user to select one
find_dev_box() {
    echo "Finding running dev boxes" >&2
    local aisi_output
    local aisi_exit_code

    aisi_output=$(aisi list-instances 2>&1) || aisi_exit_code=$?

    if [[ -n "$aisi_exit_code" ]]; then
        echo "Error: aisi list-instances: $aisi_output" >&2
        exit 1
    fi

    # Get all running instances, sorted by TTL (most recent first)
    # TTL format: 2d, -5d, 1h, etc. Sort numerically, with positive values first
    local running_instances
    running_instances=$(echo "$aisi_output" | awk '/running/ {print $4, $1}' | sort -rn -k1 | awk '{print $2}')

    if [[ -z "$running_instances" ]]; then
        echo "Error: No running dev box found. Please start a dev box first." >&2
        exit 1
    fi

    # Count running instances
    local instance_count
    instance_count=$(echo "$running_instances" | wc -l | tr -d ' ')

    if [[ "$instance_count" -eq 1 ]]; then
        # Only one running instance, use it
        echo "$running_instances"
    else
        # Multiple running instances, prompt user to select with numbered menu
        echo "Multiple running dev boxes found:" >&2
        local selected_box
        select selected_box in $running_instances; do
            if [[ -n "$selected_box" ]]; then
                echo "$selected_box"
                return
            else
                echo "Invalid selection. Please enter a number from the list." >&2
            fi
        done
    fi
}

# We authenticate to Isambard on the dev box because we can't download
# clifton cli locally without going through ICS approval.
auth_clifton_on_dev_box() {
    local dev_box="$1"

    echo "Running clifton auth and ssh-config write on dev box"
    ssh -o LogLevel=ERROR -q -T "$dev_box" << EOF
set -euo pipefail
if ! command -v clifton >/dev/null 2>&1; then
    echo "Installing clifton to $dev_box"
    mkdir -p ~/.local/bin
    curl -L https://github.com/isambard-sc/clifton/releases/latest/download/clifton-linux-musl-x86_64 -o ~/.local/bin/clifton
    chmod u+x ~/.local/bin/clifton
    export PATH="\$HOME/.local/bin:\$PATH"
fi
clifton auth -i "~/.ssh/$AISI_PRIVATE_KEY"
clifton ssh-config write
EOF
    # TODO add ssh-agent setup in dev box to allow agent forwarding? or is this not needed bc we're going straight from local to isambard?
}

# We need clifton's auth'd cert and config locally to connect directly from local->Isambard for VSCode Remote-SSH
copy_clifton_auth_from_dev_box() {
    local dev_box="$1"

    echo "Copying ssh config files from dev box"
    mkdir -p "$SSH_CONFIG_DIR"

    scp -q -o LogLevel=ERROR "$dev_box:~/.ssh/$CONFIG_CLIFTON_FILENAME" "$CONFIG_CLIFTON_PATH" || {
        echo "Failed to copy $CONFIG_CLIFTON_FILENAME, may not exist on remote"
        exit 1
    }

    # Copy clifton cache directory which contains certificates
    echo "Copying clifton cache directory from dev box"
    mkdir -p "$HOME/.cache"
    scp -q -r -o LogLevel=ERROR "$dev_box:~/.cache/clifton" "$HOME/.cache/" || {
        echo "Warning: Failed to copy clifton cache directory, may not exist on remote"
    }

    # Fix hardcoded home directories for local use
    if [[ -f "$CONFIG_CLIFTON_PATH" ]]; then
        # Replace absolute paths like /home/ubuntu/.ssh with ~/.ssh
        sed_inplace 's|/[^ ]*/\.ssh|~/.ssh|g' "$CONFIG_CLIFTON_PATH"
        # Replace other absolute home paths like /home/ubuntu/.cache with local $HOME
        sed_inplace "s|/home/[^/]*/|$HOME/|g" "$CONFIG_CLIFTON_PATH"
    fi

    if [[ -f "$HOME/.cache/clifton/brics.json" ]]; then
        sed_inplace "s|/home/[^/]*/|$HOME/|g" "$HOME/.cache/clifton/brics.json"
    fi
}

include_clifton_ssh_configs() {
    if ! grep -q "Include.*$CONFIG_CLIFTON_OVERRIDE_FILENAME" "$SSH_CONFIG" 2>/dev/null || \
       ! grep -q "Include.*$CONFIG_CLIFTON_FILENAME" "$SSH_CONFIG" 2>/dev/null; then

        # Backup existing config
        [[ -f "$SSH_CONFIG" ]] && cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"

        # Create new config with includes at the top
        local tmp_file
        tmp_file=$(mktemp)
        {
            # The override file must come first to take precedence for ProxyJump settings.
            # Any keys not set in the override will fall back to the main clifton config.
            echo "Include $CONFIG_CLIFTON_OVERRIDE_PATH"
            echo "Include $CONFIG_CLIFTON_PATH"
            [[ -f "$SSH_CONFIG" ]] && cat "$SSH_CONFIG"
        } > "$tmp_file" && mv "$tmp_file" "$SSH_CONFIG"
    fi
}

override_clifton_ssh_hosts() {
    local dev_box="$1"

    echo "Adding override configuration $CONFIG_CLIFTON_OVERRIDE_FILENAME for Isambard hosts"

    if [[ ! -f "$CONFIG_CLIFTON_PATH" ]]; then
        echo "$CONFIG_CLIFTON_PATH not found, cannot write Isambard ssh configuration"
        exit 1
    fi

    # Extract hosts with User entries from config_clifton and group by project, e.g. a5p.aip1.isambard
    local isambard_hosts
    isambard_hosts=$(awk '/^Host / {host=$2} /^[[:space:]]*User / {print host}' "$CONFIG_CLIFTON_PATH" | sort -u)

    # Get unique projects, e.g. aip1
    local projects
    projects=$(echo "$isambard_hosts" | sed -n 's/^[^.]*\.\([^.]*\)\.isambard$/\1/p' | sort -u)

    if [[ -z "$projects" ]]; then
        echo "No Isambard hosts found in $CONFIG_CLIFTON_FILENAME"
        return
    fi

    # Extract the username from one of the Isambard hosts, e.g. smith.a5p
    local isambard_user
    isambard_user=$(awk '/^Host .+\.isambard$/ {host=$2} /^[[:space:]]*User / && host ~ /\.isambard$/ {print $2; exit}' "$CONFIG_CLIFTON_PATH")

    if [[ -z "$isambard_user" ]]; then
        echo "Error: Could not extract Isambard username from $CONFIG_CLIFTON_FILENAME"
        exit 1
    fi

    # Always overwrite the overrides file with fresh configuration
    cat > "$CONFIG_CLIFTON_OVERRIDE_PATH" << EOF
# TODO if users ever have different usernames for different projects, we'll need individual blocks per jump host
Host jump.*.isambard
    # We need to explicitly set the user for the 2nd Isambard jump host,
    # as the 1st EC2 jump host user is different from the Isambard user.
    User ${isambard_user}
    # Forward the ssh key through the jump host
    ForwardAgent yes

EOF

    # Add a Host block for each project
    for project in $projects; do
        local project_hosts
        project_hosts=$(echo "$isambard_hosts" | grep "\.$project\.isambard$" | tr '\n' ' ' | sed 's/ $//')

        if [[ -n "$project_hosts" ]]; then
            local project_upper
            project_upper=$(echo "$project" | tr '[:lower:]' '[:upper:]')

            # For each host, create an override entry with the specific jump host
            for host in $project_hosts; do
                cat >> "$CONFIG_CLIFTON_OVERRIDE_PATH" << EOF
# ${project_upper} host $host via dev box and jump host
Host $host
    ProxyJump $dev_box,jump.$host
    # https://github.com/isambard-sc/clifton/pull/119
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    IPQoS none
    # Forward the ssh key to the login node
    ForwardAgent yes

EOF
            done
            echo "Added $project hosts: $project_hosts"
        fi
    done

    echo "Created $CONFIG_CLIFTON_OVERRIDE_FILENAME with ProxyJump chains for hosts:"
    echo "$isambard_hosts" | sed 's/^/ - /'
}

main() {
    echo "Setting up Isambard SSH configuration"

    check_prerequisites

    local dev_box
    dev_box=$(find_dev_box)
    echo "Using dev box: $dev_box"

    auth_clifton_on_dev_box "$dev_box"
    copy_clifton_auth_from_dev_box "$dev_box"
    include_clifton_ssh_configs
    override_clifton_ssh_hosts "$dev_box"

    echo "You can now connect to Isambard login nodes directly via SSH and VSCode."
}

main
