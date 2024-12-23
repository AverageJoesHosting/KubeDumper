# KubeDumper

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![GitHub Issues](https://img.shields.io/github/issues/AverageJoesHosting/KubeDumper.svg)
![GitHub Stars](https://img.shields.io/github/stars/AverageJoesHosting/KubeDumper.svg)

## Overview

**KubeDumper** is a comprehensive Kubernetes audit and data collection tool developed by **Average Joe's Hosting LLC**. It is designed to gather security insights, configuration details, and meta information from your Kubernetes cluster. The results are logically organized for easy analysis and troubleshooting, making it an essential tool for developers and security professionals aiming to ensure the integrity and security of their Kubernetes environments.

## Features

### Meta Collection
- **Cluster Information:** Gather cluster info, nodes, namespaces, API resources, versioning, and configuration contexts.
- **Kubernetes Dashboard:** Identify the Kubernetes dashboard, if deployed.
- **Custom Resources (CRs):** Collect all custom resources (CRs) and organize them for analysis.

### Comprehensive Auditing
Perform detailed checks on Kubernetes resources:
- **Secrets:** Identify secrets with potentially exposed sensitive data.
- **Environment Variables:** Analyze sensitive environment variables in pods.
- **Privileged/Root Pods:** Detect pods running with elevated privileges or as root.
- **API Access:** Identify overly permissive API access and anonymous user capabilities.
- **Ingress and Egress Configurations:**
  - Detect misconfigured ingress resources (e.g., missing TLS).
  - Identify unrestricted or overly permissive egress configurations.
- **RBAC:** Check RBAC configurations for:
  - Misconfigurations and excessive permissions.
  - Accounts with `cluster-admin` roles.
  - Deprecated RBAC APIs.
- **Pod Security Contexts:** Detect exploitable security context configurations.
- **Host Settings:**
  - Host Networking: Pods using `hostNetwork`.
  - Host PID: Exploitable `hostPID` settings.
  - Host Path: Check for exploitable `hostPath` volume mounts.
- **Helm Tiller:** Locate and report Helm Tiller components in the cluster.
- **Exposed API Endpoints:** Identify publicly accessible API server endpoints.
- **Pod Security:**
  - Analyze Pod Security Admission (PSA) configurations.
  - Evaluate Pod Security Policies (PSP) for outdated configurations.
- **Failed Pods:** Capture details of pods in failed states.
- **Resource Limits and Requests:** Verify resource configurations for all pods.

### Benchmarking and Scoring
- **kube-bench:** Run CIS Kubernetes Benchmark tests to assess cluster security.
- **kube-score:** Analyze downloaded manifests for best practices.

### Flexible Operations
- Run all checks at once or select specific modules.
- Dry-run mode for previewing actions without execution.
- Verbose mode for detailed logging.

### Threaded Execution
Run multiple checks in parallel using `--threads` for faster audits.  
**Note:** The threading logic is a work in progress and may have errors. For guaranteed stability, use the standard or sequential version, which is fully functional.

## Installation

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/AverageJoesHosting/KubeDumper.git
   ```

2. **Navigate to the Directory:**
   ```bash
   cd KubeDumper
   ```

3. **Make the Script Executable:**
   ```bash
   chmod +x kubeDumper.sh
   ```

4. **(Optional) Move the Script to a Directory in Your `PATH`:**
   ```bash
   sudo mv kubeDumper.sh /usr/local/bin/kubedumper
   ```

## Prerequisites

Ensure the following tools are installed and accessible in your system's `PATH`:

- **kubectl:** For interacting with Kubernetes clusters.
- **jq:** Lightweight command-line JSON processor.
- **kube-bench** (optional): For CIS Benchmark scans.
- **kube-score** (optional): For manifest analysis.
- **GNU Parallel** (optional): For parallelizing checks.

## Usage

Run the `kubeDumper.sh` script with the desired options:

```bash
./kubeDumper.sh [options]
```

Or, if moved to `PATH`:

```bash
kubedumper [options]
```

### Options

#### General
- `-n <namespace(s)>`: Specify namespaces (comma-separated) to audit (default: all).
- `-o <output_dir>`: Set output directory (default: `./k8s_audit_results`).
- `--format <text|json|html>`: Output format (default: `text`).
- `--all-checks`: Run all available checks.
- `--meta`: Collect cluster-wide meta information.
- `--dry-run`: Preview actions without executing.
- `--verbose`: Enable detailed logs.
- `--threads <num>`: Number of threads for parallel checks (default: 1).
- `-h, --help`: Display the help menu.

#### Specific Checks
- `--check-secrets`
- `--check-env-vars`
- `--check-privileged`
- `--check-api-access`
- `--check-ingress`
- `--check-egress`
- `--check-rbac`
- `--check-labels`
- `--check-failed-pods`
- `--check-resources`
- `--check-security-context`
- `--check-host-network`
- `--check-hostpid`
- `--check-host-path-mount`
- `--check-helm-tiller`
- `--check-exposed-api-endpoints`
- `--check-pod-security-admission`
- `--download-manifests`: Optionally analyze manifests using `kube-score`.
- `--check-kube-bench`

## Examples

1. **Audit All Namespaces and Collect Meta Information:**
   ```bash
   ./kubeDumper.sh --all-checks --meta
   ```

2. **Audit a Specific Namespace for RBAC Misconfigurations:**
   ```bash
   ./kubeDumper.sh -n kube-system --check-rbac
   ```

3. **Save Results to a Custom Directory:**
   ```bash
   ./kubeDumper.sh --all-checks -o /tmp/k8s_audit_results
   ```

4. **Run All Checks with Verbose Logging:**
   ```bash
   ./kubeDumper.sh --all-checks --verbose
   ```

5. **Analyze Manifests Using `kube-score`:**
   ```bash
   ./kubeDumper.sh --download-manifests --check-kube-score
   ```

## Output Structure

```
<output_dir>/
├── meta/
│   ├── cluster_info.txt
│   ├── nodes.txt
│   ├── namespaces.txt
│   ├── api_resources.txt
│   ├── version.txt
│   ├── config_context.txt
│   ├── dashboard_info.txt
├── manifests/
│   └── <namespace>/
│       ├── pods.yaml
│       ├── services.yaml
│       └── ...
├── kube_score/
│   ├── pods_score.txt
│   ├── services_score.txt
│   └── ...
├── checks/
│   ├── exposed_secrets/
│   │   └── <namespace>_secrets.txt
│   ├── privileged_pods.txt
│   ├── ingress/
│   │   └── <namespace>_ingress.txt
│   ├── rbac/
│   │   ├── rbac.json
│   │   ├── cluster_admin_details.txt
│   │   └── rbac_misconfigurations.txt
│   └── ...
├── summary_report.<format>
└── kubeDumper.log
```

## Logging

**KubeDumper** maintains detailed logs to assist with debugging and tracking. Logs are saved as `kubeDumper.log` in the specified output directory.

## 🤝 Contributing

We welcome contributions to improve the project:

1. **Fork the Repository:**
   Click the "Fork" button at the top right of the repository page.

2. **Clone Your Fork:**
   ```bash
   git clone https://github.com/AverageJoesHosting/KubeDumper.git
   cd KubeDumper
   ```

3. **Create a New Branch:**
   ```bash
   git checkout -b feature/YourFeatureName
   ```

4. **Make Your Changes:**
   Implement your feature or bug fix.

5. **Commit Your Changes:**
   ```bash
   git commit -m "Add your commit message"
   ```

6. **Push to Your Fork:**
   ```bash
   git push origin feature/YourFeatureName
   ```

7. **Create a Pull Request:**
   Go to the original repository and click "Compare & pull request" to submit your changes.

## 📜 License

This project is licensed under the [MIT License](LICENSE).

## 📞 Support

For questions or assistance, reach out to Average Joe's Hosting:

- 🌐 **Website:** [AverageJoesHosting.com](https://AverageJoesHosting.com)
- 📧 **Email:** [helpme@averagejoeshosting.com](mailto:helpme@averagejoeshosting.com)
- ☎️ **Phone:** (888) 563-1216

## 👋 About Average Joe's Hosting

Average Joe's Hosting specializes in delivering affordable, high-quality technology solutions to small businesses and organizations. Our mission is to make security and technology accessible to everyone.

Let’s work together to secure the web, one test at a time! 🌟

## Follow Us on Social Media

- 🐦 **Twitter:** [@AverageJoesHost](https://twitter.com/AverageJoesHost)
- 🎥 **YouTube:** [Average Joe's Hosting on YouTube](https://www.youtube.com/@AverageJoesHosting)
- 👥 **Facebook:** [Average Joe's Hosting on Facebook](https://www.facebook.com/AverageJoesHosting)
- 💼 **LinkedIn:** [Average Joe's Hosting on LinkedIn](https://www.linkedin.com/company/averagejoeshosting/)

🎉 Get started with Automation Booster and let your Discord server do the work for you!

---

> **Note:** Ensure all placeholder URLs and contact information are updated with your actual details to maintain accurate and professional communication channels.