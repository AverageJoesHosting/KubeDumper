# KubeDumper

**KubeDumper** is a Kubernetes audit and data collection tool designed to gather security insights, configuration details, and meta information from your cluster. The results are logically organized for easy analysis and troubleshooting.

## Features

- Collect meta artifacts like cluster information, nodes, namespaces, and API resources.
- Audit Kubernetes resources for:
  - Exposed secrets
  - Sensitive environment variables
  - Privileged/root pods
  - Misconfigured API access and ingress
- Collect all Kubernetes manifests for detailed analysis.
- Flexible output location option for saving results to a custom directory.

## Usage

`./kubeDumper.sh [options]`

### Options

- `-n <namespace>`: Specify a namespace to audit (default: all namespaces).
- `-o <output_dir>`: Specify an output directory for results (default: `./k8s_audit_results`).
- `--check-secrets`: Check for exposed secrets.
- `--check-env-vars`: Check for sensitive environment variables.
- `--check-privileged`: Check for privileged/root pods.
- `--check-api-access`: Check for insecure API access.
- `--check-ingress`: Check for misconfigured services/ingress.
- `--collect-manifests`: Collect all manifests for the specified namespace or cluster.
- `--all-checks`: Run all checks.
- `--meta`: Collect meta artifacts about the cluster.
- `-h, --help`: Display help menu.

## Examples

### Audit all namespaces and collect meta information:
```bash
./kubeDumper.sh --all-checks
```

### Audit a specific namespace:
```bash
./kubeDumper.sh -n my-namespace --check-secrets
```

### Save results to a custom output directory:
```bash
./kubeDumper.sh --all-checks -o /path/to/custom/output
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
│   ├── related_manifests/
│   └── ...
├── clusterwide/
│   ├── insecure_api_access.txt
```

## License

Licensed under the MIT License. See `LICENSE` for details.