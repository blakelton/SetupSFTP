#!/bin/bash

# Logging function
log() {
    local LOGFILE="$(basename "$0").log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Default values
SFTP_USER="sftpuser"
SFTP_GROUP="sftpusers"
SFTP_DIR="/srv/sftp/shared"
SFTP_PORT=22
SILENT_MODE=false
SILENT_PASSWORD=""

# Function to display usage and description
usage() {
    echo "Usage: $0 [-u <username>] [-g <group>] [-d <directory>] [-p <port>] [-s <password>] [-h|-help]"
    echo ""
    echo "Options:"
    echo "  -u: Define the SFTP username (default: sftpuser)"
    echo "      This is the user account that will be created for SFTP access."
    echo ""
    echo "  -g: Define the SFTP user group (default: sftpusers)"
    echo "      The group to which the SFTP user belongs. This group will have control over the shared directory."
    echo ""
    echo "  -d: Define the SFTP shared directory (default: /srv/sftp/shared)"
    echo "      The directory where files can be uploaded and stored. The directory must have at least two layers, e.g., /srv/sftp/shared."
    echo "      The script ensures the correct permissions and ownership are set for secure file transfer."
    echo ""
    echo "  -p: Define the SSH port (default: 22)"
    echo "      This option allows changing the SSH port from the default (22) to a custom port, enhancing security."
    echo "      The firewall is configured automatically to allow traffic through this port."
    echo ""
    echo "  -s: Silent mode, requires a password as the argument"
    echo "      This mode allows the script to run without user interaction, useful for automated setups. The provided password is"
    echo "      assigned to the SFTP user without prompting. Ensure the password is strong."
    echo ""
    echo "  -h, -help: Display this help message"
    echo "      Use this option to see the usage instructions and information about the available options."
    echo ""
    echo "Description:"
    echo "This script sets up a secure SFTP server with the following features:"
    echo "  - Detects the operating system (Ubuntu/Debian or CentOS/AlmaLinux) and installs required packages."
    echo "  - Creates a new SFTP user and group."
    echo "  - Configures an SFTP directory with chroot jail to isolate the user to their directory for security."
    echo "  - Customizable SSH port configuration, with automatic firewall updates to secure the server."
    echo "  - Silent mode for automation, allowing the script to run without user interaction."
    echo "  - All actions are logged to a .log file with timestamps for auditing and troubleshooting."
    echo ""
    echo "Examples:"
    echo "  1. Basic usage with default options:"
    echo "     $0"
    echo ""
    echo "  2. Specify a custom user, group, and directory:"
    echo "     $0 -u myuser -g mygroup -d /srv/sftp/myshare"
    echo ""
    echo "  3. Set a custom SSH port and run in silent mode:"
    echo "     $0 -u sftpuser -g sftpgroup -d /srv/sftp/shared -p 2222 -s mypassword"
    echo ""
    echo "In case of any issues, check the generated log file for detailed information about actions and errors."
    exit 1
}

# Function to set up firewall rules
setup_firewall() {
    if [[ "$OS" =~ ^(centos|almalinux)$ ]]; then
        if ! sudo firewall-cmd --list-ports | grep -q "${SFTP_PORT}/tcp"; then
            sudo firewall-cmd --zone=public --permanent --add-port=${SFTP_PORT}/tcp
        else
            log "Port $SFTP_PORT is already open in the firewall."
        fi
        sudo firewall-cmd --reload
        if [[ "$SFTP_PORT" != "22" ]]; then
            sudo firewall-cmd --zone=public --permanent --remove-service=ssh
            sudo firewall-cmd --reload
            log "Closed default port 22 and opened port $SFTP_PORT on $OS $VERSION."
        fi
    elif [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
        if ! sudo ufw status | grep -q "${SFTP_PORT}/tcp"; then
            sudo ufw allow ${SFTP_PORT}/tcp
        else
            log "Port $SFTP_PORT is already open in the firewall."
        fi
        if [[ "$SFTP_PORT" != "22" ]]; then
            sudo ufw delete allow OpenSSH
            sudo ufw reload
            log "Closed default port 22 and opened port $SFTP_PORT on $OS $VERSION."
        fi
    fi
}

# Function to check and prevent redundant entries in sshd_config
ensure_sshd_config() {
    local match="Match Group $SFTP_GROUP"
    local config_block="Match Group $SFTP_GROUP
    ChrootDirectory $PARENT_DIR
    ForceCommand internal-sftp -d /$SHARED_DIR
    "
    if ! grep -q "$match" /etc/ssh/sshd_config; then
        echo "$config_block" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        log "Added SFTP configuration for $SFTP_GROUP to sshd_config."
    else
        log "SFTP configuration for $SFTP_GROUP already exists in sshd_config."
    fi
}

# Detect operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        log "Error: Unable to detect the operating system."
        exit 1
    fi
}

# Function to install required packages
install_packages() {
    if [[ "$OS" =~ ^(centos|almalinux)$ ]]; then
        sudo dnf install -y openssh-server firewalld
        sudo systemctl start sshd
        sudo systemctl enable sshd
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
        log "Packages installed on $OS $VERSION."
    elif [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
        sudo apt update
        sudo apt install -y openssh-server ufw
        sudo systemctl start ssh
        sudo systemctl enable ssh
        log "Packages installed on $OS $VERSION."
    else
        log "Error: Unsupported operating system."
        exit 1
    fi
}

# Function to check directory levels and split parent and shared directories
check_directory_levels() {
    local path=$1
    if [[ $(echo "$path" | grep -o "/" | wc -l) -lt 2 ]]; then
        log "Error: The SFTP directory must have at least two directory levels (e.g., /srv/sftp/shared)."
        exit 1
    fi
    
    # Split the path into parent and shared directories
    PARENT_DIR=$(dirname "$SFTP_DIR")
    SHARED_DIR=$(basename "$SFTP_DIR")
    
    log "Parent directory: $PARENT_DIR"
    log "Shared directory: $SHARED_DIR"
}

# Function to create the SFTP directory if it doesn't exist and set proper ownership
create_sftp_directory() {

    # Ensure the parent directory is owned by root
    if [ ! -d "$PARENT_DIR" ]; then
        sudo mkdir -p "$PARENT_DIR"
        log "Created parent directory $PARENT_DIR owned by root."
    else
        log "Parent directory $PARENT_DIR already exists."
    fi
    sudo chown root:root "$PARENT_DIR"
    sudo chmod 755 "$PARENT_DIR"
    log "Using $PARENT_DIR Owned by root:root for security."
    
    # Create the shared directory and set ownership to sftpuser
    if [ ! -d "$SFTP_DIR" ]; then
        sudo mkdir -p "$SFTP_DIR"
        sudo chown $SFTP_USER:$SFTP_GROUP "$SFTP_DIR"
        sudo chmod 775 "$SFTP_DIR"
        log "Created SFTP directory $SFTP_DIR"
    else
        log "SFTP directory $SFTP_DIR already exists."
    fi
    sudo chown $SFTP_USER:$SFTP_GROUP "$SFTP_DIR"
    sudo chmod 775 "$SFTP_DIR"
    log "Using $SFTP_DIR Owned by $SFTP_USER:$SFTP_GROUP for security."
}

# Function to handle interactive confirmation
confirmation_prompt() {
    echo "/*****************************************"
    echo "THE FOLLOWING SETTINGS WILL BE USED:"
    echo "Operating System: $OS $VERSION"
    echo "SFTP User Group: $SFTP_GROUP"
    echo "SFTP User: $SFTP_USER"
    echo "SFTP Directory: $SFTP_DIR"
    echo "Parent Directory: $PARENT_DIR"
    echo "Shared Directory: /$SHARED_DIR"
    echo "SFTP Port: $SFTP_PORT"
    echo ""
    echo "This will also install and enable:"
    echo "openssh-server"
    echo "On Ubuntu/Debian: ufw"
    echo "On AlmaLinux/CentOS: firewalld"
    echo "*****************************************/"
    echo "Do you want to continue? [yes]"
    read confirmation
    # If enter is pressed or the response is 'yes', proceed
    if [[ -z "$confirmation" || "$confirmation" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        log "User confirmed the setup."
    else
        log "User canceled the setup."
        exit 0
    fi
}

# Function to create the SFTP user and set the password
create_sftp_user() {
    sudo groupadd -f $SFTP_GROUP
    
    if ! id "$SFTP_USER" &>/dev/null; then
        sudo useradd -M -G $SFTP_GROUP -s /bin/bash $SFTP_USER
        log "User $SFTP_USER created and added to group $SFTP_GROUP."
    else
        log "User $SFTP_USER already exists."
    fi
    
    if [ "$SILENT_MODE" = true ] && [ -z "$SILENT_PASSWORD" ]; then
        log "Error: Silent mode requires a non-empty password."
        exit 1
    elif [ "$SILENT_MODE" = false ]; then
        echo "What password should be used for $SFTP_USER?"
        sudo passwd $SFTP_USER
    else
        echo "$SILENT_PASSWORD" | sudo passwd --stdin $SFTP_USER
        log "Password for $SFTP_USER was set in silent mode."
    fi

    log "Created user $SFTP_USER and added to group $SFTP_GROUP."
}

# Parse command line arguments
while getopts "u:g:d:p:s:h" opt; do
    case $opt in
        u) SFTP_USER=$OPTARG ;;
        g) SFTP_GROUP=$OPTARG ;;
        d) SFTP_DIR=$OPTARG ;;
        p) SFTP_PORT=$OPTARG ;;
        s) SILENT_MODE=true; SILENT_PASSWORD=$OPTARG ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check if the shared directory is in the user's home directory
if [[ "$SFTP_DIR" == "/home/$SFTP_USER"* ]]; then
    log "Error: The specified directory ($SFTP_DIR) is within the user's home directory."
    exit 1
fi

# Start script execution
log "Starting SFTP setup script."
detect_os

# Check if the directory has at least two levels and split it
check_directory_levels "$SFTP_DIR"

# Show confirmation unless in silent mode
if [ "$SILENT_MODE" = false ]; then
    confirmation_prompt
fi

install_packages
create_sftp_directory
create_sftp_user

# Ensure SSH configuration is set up properly
ensure_sshd_config

# Set up firewall
setup_firewall

# Restart SSH to apply changes
if [[ "$OS" =~ ^(centos|almalinux)$ ]]; then
    sudo systemctl restart sshd
    if [ $? -eq 0 ]; then
        log "SSH service restarted successfully."
    else
        log "Error restarting SSH service."
        exit 1
    fi
elif [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
    sudo systemctl restart ssh
    if [ $? -eq 0 ]; then
        log "SSH service restarted successfully."
    else
        log "Error restarting SSH service."
        exit 1
    fi
fi

log "SFTP setup complete. You can now connect using: sftp -P $SFTP_PORT $SFTP_USER@<your-server>"
exit 0
