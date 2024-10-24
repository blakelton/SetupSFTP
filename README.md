
# SFTP Setup Script
This is shell script to automate the setup of a secure SFTP (Secure File Transfer Protocol) server on both Ubuntu/Debian and CentOS/AlmaLinux systems. This script allows (but does not require) you to define a custom SFTP user, group, shared directory, and SSH port for enhanced security. This script can also be ran silently for automated initialization processes. Have a lot of fun!

## Features
- Automatically detects operating system (Ubuntu/Debian or CentOS/AlmaLinux).
- Creates SFTP user and group.
- Configures SFTP with chroot jail for security.
- Allows specification of a custom SSH port (default is 22).
- Automatically configures firewall rules to match the chosen SSH port.
- Supports silent mode for automation.
- Logs all actions for auditing and troubleshooting.

## Prerequisites
- Root or sudo access is required to run the script.
- Ensure that your system supports `firewalld` (CentOS/AlmaLinux) or `ufw` (Ubuntu/Debian).

## Installation

1. Clone the repository or download the script:
    ```bash
    git clone git@github.com:blakelton/SetupSFTP.git
    cd ./SetupSFTP
    ```

2. Ensure the script is executable:
    ```bash
    chmod +x SetupSFTP.sh
    ```

3. Run the script with the required options (or use defaults):
    ``` bash
    sudo ./SetupSFTP.sh
    ```

## Usage

### Command:
```bash
sudo ./SetupSFTP.sh [-u <username>] [-g <group>] [-d <directory>] [-p <port>] [-s <password>] [-h|-help]
```

### Options:
- `-u <username>` : Define the SFTP username (default: `sftpuser`). This is the user account that will be created for SFTP access.
- `-g <group>`: Define the SFTP user group (default: `sftpusers`). The group to which the SFTP user belongs, controlling the shared directory.
- `-d <directory>`: Define the SFTP shared directory (default: `/srv/sftp/shared`). The directory where files can be uploaded and stored. This directory must have at least two layers, e.g., `/srv/sftp/shared`.
- `-p <port>`: Define the SSH port (default: `22`). This allows you to specify a custom port for added security.
- `-s <password>`: Silent mode, requires a password as the argument. This mode allows the script to run without user interaction. The provided password is assigned to the SFTP user without prompting.
- `-h, -help`: Display this help message, showing available options and their usage.

### Examples:

1. **Basic Usage with Defaults**:
   ```bash
   sudo ./SetupSFTP.sh
   ```
   This will create the user `sftpuser`, group `sftpusers`, and shared directory `/srv/sftp/shared` with default settings.

2. **Specify a Custom User, Group, and Directory**:
   ```bash
   sudo ./SetupSFTP.sh -u myuser -g mygroup -d /srv/sftp/myshare
   ```
   This creates a new SFTP user `myuser`, adds them to the `mygroup`, and sets the shared directory to `/srv/sftp/myshare`.

3. **Set a Custom SSH Port and Run in Silent Mode**:
   ```bash
   sudo ./SetupSFTP.sh -u sftpuser -g sftpgroup -d /srv/sftp/shared -p 2222 -s mypassword
   ```
   This configures the SFTP server to use SSH on port `2222`, and sets the password for `sftpuser` to `mypassword` in silent mode, ideal for automation.

## Logging
All actions performed by the script are logged in a file named `SetupSFTP.log` in the same directory where the script is executed. This includes timestamps, success/failure messages, and warnings. The log file helps with auditing and troubleshooting.

## Troubleshooting
- **SSH Service Issues**: If SSH fails to restart, check the log file for error messages and ensure the configuration file `/etc/ssh/sshd_config` has no syntax errors.
- **Permission Denied Errors**: Ensure that the shared directory is outside the user's home directory and that proper ownership and permissions are set (root should own the parent directory, and the SFTP user should own the shared directory).
- **Firewall Configuration**: If there are firewall issues, verify that the correct ports are open using `firewalld` (CentOS/AlmaLinux) or `ufw` (Ubuntu/Debian).

## Contributing
If you'd like to contribute or report issues, please open a pull request or issue on the repository.

## License
This project is licensed under the MIT License.
