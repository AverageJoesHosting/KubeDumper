# KubeDumper

**KubeDumper** is a comprehensive Kubernetes audit and data collection tool designed to gather security insights, configuration details, and meta information from your cluster. The results are logically organized for easy analysis and troubleshooting.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
  - [Options](#options)
- [Examples](#examples)
- [Output Structure](#output-structure)
- [Logging](#logging)
- [License](#license)

## Features

- **Meta Collection**: Gather cluster information, node details, namespaces, API resources, and Kubernetes configuration context.
- **Comprehensive Auditing**: Perform in-depth checks for:
  - **Exposed Secrets**: Identify secrets containing potentially sensitive data.
  - **Sensitive Environment Variables**: Review pods for environment variables that may expose credentials.
  - **Privileged/Root Pods**: Detect pods running with elevated privileges or as root.
  - **Insecure API Access**: Confirm if anonymous or overly broad permissions are granted to unauthenticated users.
  - **Misconfigured Ingress**: Identify ingress resources missing TLS or secure configurations.
  - **RBAC Misconfigurations**: Examine roles, bindings, and cluster roles for overly permissive policies.
  - **Missing Labels/Annotations**: Ensure pods and other resources carry required labels (e.g., `app` label).
  - **Failed Pods**: Capture details of pods stuck in failed states for troubleshooting.
  - **Resource Limits and Requests**: Verify that all pods have proper resource requests and limits set.
- **Run All Checks at Once**: Quickly assess your entire cluster with a single command.
- **Flexible Output**:
  - Specify custom output directories.
  - Support for multiple output formats: `text`, `json`, and `html`.
  - Dry-run mode to simulate actions without making changes.
  - Verbose mode for detailed logs.
- **Threaded Execution**:
  - Utilize the `--threads <num>` option to run checks in parallel for faster audits on large clusters (requires GNU Parallel).
- **Logging**:
  - Detailed logging with timestamps for traceability.
  - Logs are saved within the specified output directory.

## Prerequisites

Before using **KubeDumper**, ensure that the following tools are installed and accessible in your system's `PATH`:

- **kubectl**: Command-line tool for interacting with Kubernetes clusters.
- **jq**: Lightweight and flexible command-line JSON processor.
- **GNU Parallel** (optional): For running checks in parallel when using the `--threads` option.

### Installing Dependencies

#### Install `kubectl`

Follow the official [Kubernetes documentation](https://kubernetes.io/docs/tasks/tools/install-kubectl/) to install `kubectl`.

#### Install `jq`

- **macOS**:
  ```bash
  brew install jq
  ```

- **Ubuntu/Debian**:
  ```bash
  sudo apt-get update
  sudo apt-get install -y jq
  ```

- **CentOS/RHEL**:
  ```bash
  sudo yum install -y epel-release
  sudo yum install -y jq
  ```

#### Install GNU Parallel (Optional)

- **macOS**:
  ```bash
  brew install parallel
  ```

- **Ubuntu/Debian**:
  ```bash
  sudo apt-get update
  sudo apt-get install -y parallel
  ```

- **CentOS/RHEL**:
  ```bash
  sudo yum install -y parallel
  ```

**Note**: While GNU Parallel is optional, it is required if you intend to run checks in parallel using the `--threads` option.

## Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/yourusername/kubedumper.git
   ```

2. **Navigate to the Directory**:
   ```bash
   cd kubedumper
   ```

3. **Make the Script Executable**:
   ```bash
   chmod +x kubeDumper.sh
   ```

4. **(Optional) Move to a Directory in PATH**:
   ```bash
   sudo mv kubeDumper.sh /usr/local/bin/kubedumper
   ```

   This allows you to run `kubedumper` from anywhere in your terminal.

## Usage

```bash
./kubeDumper.sh [options]
```

Or, if moved to a directory in `PATH`:

```bash
kubedumper [options]
```

### Options

- `-n <namespace(s)>`: Specify one or more namespaces (comma-separated) to audit (default: all).
- `-o <output_dir>`: Specify a custom output directory for results (default: `./k8s_audit_results`).
- `--format <text|json|html>`: Specify output format for the summary report (default: `text`).
- `--check-secrets`: Check for exposed secrets.
- `--check-env-vars`: Check for sensitive environment variables.
- `--check-privileged`: Check for privileged/root pods.
- `--check-api-access`: Check for insecure API access.
- `--check-ingress`: Check for misconfigured ingress resources.
- `--check-rbac`: Check for RBAC misconfigurations.
- `--check-labels`: Check for missing labels/annotations on resources.
- `--check-failed-pods`: Check and capture details of failed pods.
- `--check-resources`: Check for missing resource requests and limits.
- `--download-manifests`: Download all Kubernetes manifests to the output directory.
- `--all-checks`: Run all available checks.
- `--meta`: Collect meta artifacts about the cluster.
- `--dry-run`: Preview actions without executing changes.
- `--verbose`: Enable detailed logging to assist with debugging.
- `--threads <num>`: Number of threads to run checks in parallel (default: 1).
- `-h, --help`: Display the help menu.

## Examples

### 1. Audit All Namespaces and Collect Meta Information

```bash
./kubeDumper.sh --all-checks --meta
```

### 2. Audit a Specific Namespace for Exposed Secrets

```bash
./kubeDumper.sh -n my-namespace --check-secrets
```

### 3. Save Results to a Custom Output Directory

```bash
./kubeDumper.sh --all-checks -o /path/to/custom/output
```

### 4. Run All Checks in Parallel Using 4 Threads

```bash
./kubeDumper.sh --all-checks --threads 4
```

*Note: Ensure `GNU parallel` is installed for multi-threaded execution.*

### 5. Generate a Summary Report in JSON Format

```bash
./kubeDumper.sh --all-checks --format json
```

### 6. Perform a Dry Run to Preview Actions Without Executing

```bash
./kubeDumper.sh --all-checks --dry-run
```

### 7. Enable Verbose Logging for Detailed Output

```bash
./kubeDumper.sh --all-checks --verbose
```

### 8. Combine Multiple Options

```bash
./kubeDumper.sh -n default,kube-system --check-secrets --check-rbac --verbose -o /tmp/kube_audit --format html
```

## Output Structure

Results are saved in a structured directory. By default, this is `./k8s_audit_results/`, but you can specify a custom location using the `-o` option.

```
<output_dir>/
├── meta/
│   ├── cluster_info.txt
│   ├── nodes.txt
│   ├── namespaces.txt
│   ├── api_resources.txt
│   ├── version.txt
│   └── config_context.txt
├── <namespace>/
│   ├── exposed_secrets/
│   │   └── <secret_name>.txt
│   ├── env_variables/
│   │   └── <pod_name>.txt
│   ├── privileged_pods/
│   │   └── privileged_pods.txt
│   ├── ingress/
│   │   └── insecure_ingress.txt
│   ├── resources/
│   │   └── missing_resources.txt
│   ├── failed_pods/
│   │   └── failed_pods.json
│   └── labels/
│       └── missing_labels.txt
├── rbac/
│   ├── rbac.json
│   └── rbac_misconfigurations.txt
├── api_access/
│   └── insecure_api_access.txt
├── manifests/
│   └── <namespace>/
│       ├── pods.yaml
│       ├── services.yaml
│       └── ... (other resources)
├── summary_report.<format>
└── kubeDumper.log
```

- **meta/**: Contains cluster-wide meta information.
- **<namespace>/**: Each audited namespace has its own directory containing specific check results.
  - **exposed_secrets/**: Details of secrets with exposed data.
  - **env_variables/**: Sensitive environment variables found in pods.
  - **privileged_pods/**: List of privileged or root pods.
  - **ingress/**: Ingress resources missing TLS or secure configurations.
  - **resources/**: Pods missing resource requests or limits.
  - **failed_pods/**: JSON details of pods in failed states.
  - **labels/**: Pods missing required labels.
- **rbac/**: RBAC configurations and any misconfigurations detected.
- **api_access/**: Results related to API access permissions.
- **manifests/**: Downloaded Kubernetes manifests organized by namespace.
- **summary_report.<format>**: Summary of the audit in the specified format (`text`, `json`, `html`).
- **kubeDumper.log**: Detailed logs of the audit process.

## Logging

**KubeDumper** maintains a detailed log file to assist with debugging and tracking the audit process. The log file is named `kubeDumper.log` and is located within the specified `OUTPUT_DIR`.

### Verbose Mode

- When the `--verbose` option is enabled, additional log messages are displayed in the console.
- All log entries, including those not displayed in verbose mode, are saved to `kubeDumper.log` with timestamps for traceability.

**Example Log Entry:**
```
[LOG] 2024-04-27 15:30:45 Starting check_secrets.
[LOG] 2024-04-27 15:30:50 Completed check_secrets.
```

## License

Licensed under the MIT License. See `LICENSE` for details.
