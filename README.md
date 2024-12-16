# KubeDumper

**KubeDumper** is a Kubernetes audit and data collection tool designed to gather security insights, configuration details, and meta information from your cluster. The results are logically organized for easy analysis and troubleshooting.

## Features

- **Meta Collection**: Gather cluster information, node details, namespaces, API resources, and Kubernetes configuration context.
- **Comprehensive Auditing**: Check for:
  - **Exposed Secrets**: Identify secrets containing potentially sensitive data.
  - **Sensitive Environment Variables**: Review pods for environment variables that may expose credentials.
  - **Privileged/Root Pods**: Detect pods running with elevated privileges or as root.
  - **Insecure API Access**: Confirm if anonymous or overly broad permissions are granted to unauthenticated users.
  - **Misconfigured Ingress**: Identify ingress resources missing TLS or secure configurations.
  - **RBAC Misconfigurations**: Examine roles, bindings, and cluster roles for overly permissive policies.
  - **Missing Labels/Annotations**: Ensure pods and other resources carry required labels (e.g., `app` label).
  - **Failed Pods**: Capture details of pods stuck in failed states for troubleshooting.
  - **Resource Limits and Requests**: Verify that all pods have proper resource requests and limits set.
- **Run All Checks**: Quickly assess your entire cluster at once.
- **Flexible Output**:
  - Specify custom output directories.
  - Supports a dry-run mode to simulate actions without making changes.
  - Verbose mode for detailed logging.
  - Multiple output formats (text, json, html) planned (default: text).

## Usage

```bash
./kubeDumper.sh [options]
```

### Options

- `-n <namespace(s)>`: Specify one or more namespaces (comma-separated) to audit (default: all).
- `-o <output_dir>`: Specify a custom output directory for results (default: `./k8s_audit_results`).
- `--format <text|json|html>`: Specify output format (default: `text`).
- `--check-secrets`: Check for exposed secrets.
- `--check-env-vars`: Check for sensitive environment variables.
- `--check-privileged`: Check for privileged/root pods.
- `--check-api-access`: Check for insecure API access.
- `--check-ingress`: Check for misconfigured ingress resources.
- `--check-rbac`: Check for RBAC misconfigurations.
- `--check-labels`: Check for missing labels/annotations on resources.
- `--check-failed-pods`: Check and capture details of failed pods.
- `--check-resources`: Check for missing resource requests and limits.
- `--all-checks`: Run all available checks.
- `--meta`: Collect meta artifacts about the cluster.
- `--dry-run`: Preview actions without executing changes.
- `--verbose`: Enable detailed logging to assist with debugging.
- `-h, --help`: Display this help menu.

## Examples

### Audit all namespaces and collect meta information:
```bash
./kubeDumper.sh --all-checks
```

### Audit a specific namespace for exposed secrets:
```bash
./kubeDumper.sh -n my-namespace --check-secrets
```

### Save results to a custom output directory:
```bash
./kubeDumper.sh --all-checks -o /path/to/custom/output
```

### Dry Run Example (no changes, just preview):
```bash
./kubeDumper.sh --all-checks --dry-run
```

### Verbose Logging Example:
```bash
./kubeDumper.sh --all-checks --verbose
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
│   ├── env_variables/
│   ├── privileged_pods/
│   ├── ingress/
│   ├── resources/
│   ├── failed_pods/
│   └── labels/
├── rbac/
│   ├── rbac.json
└── clusterwide/
    └── api_access/
        └── insecure_api_access.txt

summary_report.txt
```

The structure may vary based on which checks are run and how many namespaces you have. Each category of result is stored in a dedicated subdirectory for easy navigation and analysis.

## License

Licensed under the MIT License. See `LICENSE` for details.
