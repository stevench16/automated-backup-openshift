# Automated Backup Script for OpenShift

## Description

This script, `automated-backup-openshift.sh`, is designed to automate the backup process of an OpenShift cluster's critical data. It creates snapshots and static Kubernetes resource backups, stores them locally, and transfers them to an Azure File Share for secure storage.

## Features

- Automates login to OpenShift using a token.
- Executes the OpenShift `cluster-backup.sh` script on specified nodes.
- Validates the generation of backup files.
- Mounts an Azure File Share for secure backup storage.
- Transfers generated backup files to the Azure File Share.
- Logs backup details locally.
- Cleans up local temporary files after transfer.

## Prerequisites

1. **Dependencies:**
   - Bash shell.
   - OpenShift CLI (`oc`).
   - Azure CLI (optional for setting up Azure File Share).

2. **Environment Setup:**
   - Ensure OpenShift CLI is configured on the system where the script runs.
   - Obtain an OpenShift API token and server URL.
   - Configure Azure File Share:
     - Create an Azure File Share.
     - Obtain the storage account name, key, and file share name.

3. **Node Permissions:**
   - Ensure the script is run with sufficient permissions to debug nodes and access cluster resources.

## Usage

### Configuration

Before running the script, update the following variables as per your environment:

- OpenShift Configuration:
  ```bash
  OC_SERVER="<API_SERVER_OPENSHIFT>"
  OC_TOKEN=$(cat /opt/scripts/oc_token) # Ensure the token file exists.
  ```

- Backup Directory:
  ```bash
  BACKUP_DIR="/home/core/assets/backup"
  ```

- Azure File Share Configuration:
  ```bash
  AZURE_STORAGE_ACCOUNT="<STORAGE_ACCOUNT_NAME>"
  AZURE_FILE_SHARE="<FILE_SHARE_NAME>"
  AZURE_STORAGE_KEY="<STORAGE_KEY>"
  MOUNT_POINT="/mnt/backup-openshift-etcd"
  ```

- Nodes to Backup:
  ```bash
  NODES=("NODE MASTER 1" "NODE MASTER 2" "NODE MASTER 3")
  ```

### Running the Script

1. **Make the script executable:**
   ```bash
   chmod +x automated-backup-openshift.sh
   ```

2. **Execute the script:**
   ```bash
   ./automated-backup-openshift.sh
   ```

### Logs

The script logs backup details to the specified log file:
```bash
LOG_FILE="/var/log/backup_files.log"
```

## Script Workflow

1. Authenticate to OpenShift using the provided token.
2. Debug each specified node to:
   - Execute the `cluster-backup.sh` script.
   - Verify the generation of backup files.
3. Mount the Azure File Share.
4. Transfer backup files to the Azure File Share.
5. Log the backup operation details.
6. Clean up local files and unmount the Azure File Share.

## Error Handling

- The script includes validation steps to:
  - Ensure authentication to OpenShift is successful.
  - Verify the creation of backup files.
  - Confirm the Azure File Share is mounted and files are transferred correctly.

- If an error occurs, the script will display relevant error messages and attempt to continue with subsequent steps where applicable.

## Notes

- Ensure the script is executed with appropriate permissions.
- For production use, consider implementing additional security measures, such as encrypting sensitive variables.

## License

This script is licensed under the MIT License. See the `LICENSE` file for more details.

---

**Author:** Steven Chavez Rodriguez

**Contact:** steven_chavez16@hotmail.com
