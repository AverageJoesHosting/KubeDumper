#!/bin/bash

# Default output directory for storing audit results
OUTPUT_DIR="./k8s_audit_results"
NAMESPACE="all" # Default to all namespaces
OUTPUT_FORMAT="text" # Default output format
ALL_CHECKS=false
DRY_RUN=false
VERBOSE=false

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Function to display help menu
display_help() {
    echo -e "${CYAN}KubeDumper - Kubernetes Security Audit Tool${NC}"
    echo
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -n <namespace(s)>      Specify one or more namespaces to audit (comma-separated). Default: all namespaces."
    echo "  -o <output_dir>        Specify an output directory for results. Default: ./k8s_audit_results."
    echo "  --format <text|json|html> Specify the output format. Default: text."
    echo "  --check-secrets         Check for exposed secrets."
    echo "  --check-env-vars        Check for sensitive environment variables."
    echo "  --check-privileged      Check for privileged/root pods."
    echo "  --check-api-access      Check for insecure API access."
    echo "  --check-ingress         Check for misconfigured services/ingress."
    echo "  --check-rbac            Check for RBAC misconfigurations."
    echo "  --check-labels          Check for missing labels (e.g. 'app' label)."
    echo "  --check-failed-pods     Check for failed pods and record their details."
    echo "  --check-resources       Check for missing resource limits and requests."
    echo "  --all-checks            Run all checks."
    echo "  --meta                  Collect meta artifacts about the cluster."
    echo "  --dry-run               Preview actions without executing."
    echo "  --verbose               Enable detailed logs."
    echo "  -h, --help              Display this help menu."
    exit 0
}

# Logging function
log() {
    local message="$1"
    if $VERBOSE; then
        echo -e "${CYAN}[LOG]${NC} $message"
        echo "[LOG] $message" >> kubeDumper.log
    fi
}

# Prepare the output directory
prepare_output_directory() {
    mkdir -p "$OUTPUT_DIR" || { echo -e "${RED}Error: Failed to create output directory: $OUTPUT_DIR${NC}"; exit 1; }
    log "Output directory prepared at $OUTPUT_DIR."
}

# Collect namespaces
get_namespaces() {
    if [[ "$NAMESPACE" == "all" ]]; then
        kubectl get namespaces -o jsonpath="{.items[*].metadata.name}" 2>/dev/null || echo -e "${RED}Error retrieving namespaces.${NC}"
    else
        echo "$NAMESPACE" | tr ',' ' '
    fi
}

# Dry-run check wrapper
execute_check() {
    local check_function="$1"
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN] Would execute: $check_function${NC}"
        log "[DRY-RUN] Skipped: $check_function"
    else
        $check_function
    fi
}

# Collect meta artifacts
collect_meta_artifacts_real() {
    echo -e "${CYAN}Collecting meta artifacts...${NC}"
    local meta_dir="$OUTPUT_DIR/meta"
    mkdir -p "$meta_dir"

    kubectl cluster-info > "$meta_dir/cluster_info.txt" 2>/dev/null
    kubectl get nodes -o wide > "$meta_dir/nodes.txt" 2>/dev/null
    kubectl get namespaces > "$meta_dir/namespaces.txt" 2>/dev/null
    kubectl api-resources > "$meta_dir/api_resources.txt" 2>/dev/null
    kubectl version > "$meta_dir/version.txt" 2>/dev/null
    kubectl config view > "$meta_dir/config_context.txt" 2>/dev/null
    echo -e "${GREEN}Meta artifacts collected in $meta_dir.${NC}"
}

# Check for exposed secrets
check_exposed_secrets() {
    echo -e "${CYAN}Checking for exposed secrets...${NC}"
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/exposed_secrets"
        mkdir -p "$ns_dir"

        secrets=$(kubectl get secrets -n "$ns" -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)

        for secret in $secrets; do
            secret_file="$ns_dir/$secret.txt"
            kubectl get secret "$secret" -n "$ns" -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' > "$secret_file" 2>/dev/null
            if [[ -s "$secret_file" ]]; then
                echo "    Secret '$secret' in namespace '$ns' has exposed data: saved to $secret_file"
            else
                rm -f "$secret_file"
                echo "    Secret '$secret' in namespace '$ns' has no decodable data."
            fi
        done
    done
}

# Check environment variables
check_env_variables() {
    echo -e "${CYAN}Checking for sensitive environment variables...${NC}"
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/env_variables"
        mkdir -p "$ns_dir"

        pods=$(kubectl get pods -n "$ns" -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)

        for pod in $pods; do
            pod_file="$ns_dir/$pod.txt"
            kubectl get pod "$pod" -n "$ns" -o json | jq -r '
                .spec.containers[].env[]? | "\(.name): \(.value // "ValueFrom: " + (.valueFrom | tostring))"
            ' > "$pod_file" 2>/dev/null
            if [[ -s "$pod_file" ]]; then
                echo "    Environment variables for pod '$pod' stored in $pod_file"
            else
                rm -f "$pod_file"
                echo "    No sensitive environment variables found for pod '$pod'."
            fi
        done
    done
}

# Check for privileged/root pods
check_privileged_pods() {
    echo -e "${CYAN}Checking for privileged/root pods...${NC}"
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/privileged_pods"
        mkdir -p "$ns_dir"

        pods=$(kubectl get pods -n "$ns" -o json)
        echo "$pods" | jq -r '
            .items[] | 
            select(.spec.containers[].securityContext.privileged == true or .spec.containers[].securityContext.runAsUser == 0) | 
            .metadata.name
        ' > "$ns_dir/privileged_pods.txt"

        if [[ -s "$ns_dir/privileged_pods.txt" ]]; then
            echo "    Privileged/root pods found in namespace '$ns'. Results in $ns_dir/privileged_pods.txt"
        else
            echo "    No privileged/root pods in namespace '$ns'."
            rm -f "$ns_dir/privileged_pods.txt"
        fi
    done
}

# Check API access (anonymous should not have full access)
check_api_access() {
    echo -e "${CYAN}Checking API access for anonymous user...${NC}"
    local api_dir="$OUTPUT_DIR/api_access"
    mkdir -p "$api_dir"

    kubectl auth can-i '*' '*' --as=system:anonymous > "$api_dir/insecure_api_access.txt" 2>/dev/null
    if grep -q "yes" "$api_dir/insecure_api_access.txt"; then
        echo "    Anonymous user has broad permissions. Results in $api_dir/insecure_api_access.txt"
    else
        echo "    Anonymous access is restricted."
        # Keep the file for reference even if no 'yes' found
    fi
}

# Check ingress misconfigurations (no TLS)
check_ingress() {
    echo -e "${CYAN}Checking ingress configurations...${NC}"
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/ingress"
        mkdir -p "$ns_dir"
        kubectl get ingress -n "$ns" -o json | jq -r '
            .items[] | select(.spec.tls == null) | "\(.metadata.name) missing HTTPS configuration"
        ' > "$ns_dir/insecure_ingress.txt"

        if [[ -s "$ns_dir/insecure_ingress.txt" ]]; then
            echo "    Insecure ingress(es) found in namespace '$ns'. See $ns_dir/insecure_ingress.txt"
        else
            echo "    All ingress in namespace '$ns' have TLS configured or no ingress present."
            rm -f "$ns_dir/insecure_ingress.txt"
        fi
    done
}

# Check RBAC misconfigurations
check_rbac() {
    echo -e "${CYAN}Checking RBAC configurations...${NC}"
    rbac_dir="$OUTPUT_DIR/rbac"
    mkdir -p "$rbac_dir"

    kubectl get roles,rolebindings,clusterroles,clusterrolebindings -A -o json > "$rbac_dir/rbac.json" 2>/dev/null
    if [[ -s "$rbac_dir/rbac.json" ]]; then
        # Detect overly permissive roles (just an example heuristic)
        jq -r '
            .items[] |
            select(.rules?[]?.resources? | index("*")) |
            "Overly permissive role: \(.metadata.name) in namespace \(.metadata.namespace // "cluster-scope")"
        ' "$rbac_dir/rbac.json" > "$rbac_dir/rbac_misconfigurations.txt"
        echo "    RBAC details saved to $rbac_dir. Misconfigurations in rbac_misconfigurations.txt if any."
    else
        echo "    No RBAC data retrieved."
    fi
}

# Check missing labels (e.g. 'app' label)
check_labels() {
    echo -e "${CYAN}Checking for missing 'app' labels...${NC}"
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/labels"
        mkdir -p "$ns_dir"
        # Check pods missing 'app' label
        kubectl get pods -n "$ns" -o json | jq -r '
            .items[] |
            select(.metadata.labels.app == null) |
            "Pod \(.metadata.name) is missing app label"
        ' > "$ns_dir/missing_labels.txt"

        if [[ -s "$ns_dir/missing_labels.txt" ]]; then
            echo "    Pods missing 'app' label in namespace '$ns'. See $ns_dir/missing_labels.txt"
        else
            echo "    All pods in namespace '$ns' have 'app' labels or no pods present."
            rm -f "$ns_dir/missing_labels.txt"
        fi
    done
}

# Check for failed pods
check_failed_pods() {
    echo -e "${CYAN}Checking for failed pods...${NC}"
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/failed_pods"
        mkdir -p "$ns_dir"

        # Record all failed pods
        kubectl get pods -n "$ns" --field-selector=status.phase=Failed -o json > "$ns_dir/failed_pods.json" 2>/dev/null

        if [[ -s "$ns_dir/failed_pods.json" ]]; then
            echo "    Failed pods found in namespace '$ns'. Details in $ns_dir/failed_pods.json"
        else
            echo "    No failed pods in namespace '$ns'."
            rm -f "$ns_dir/failed_pods.json"
        fi
    done
}

# Check resource limits
check_resources() {
    echo -e "${CYAN}Checking for missing resource limits and requests...${NC}"
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/resources"
        mkdir -p "$ns_dir"

        kubectl get pods -n "$ns" -o json | jq -r '
            .items[] |
            select(.spec.containers[]? | (.resources.requests == null or .resources.limits == null)) |
            "Pod \(.metadata.name) is missing resource requests or limits"
        ' > "$ns_dir/missing_resources.txt" 2>/dev/null

        if [[ -s "$ns_dir/missing_resources.txt" ]]; then
            echo "    Pods missing resource limits/requests in namespace '$ns'. See $ns_dir/missing_resources.txt"
        else
            echo "    All pods in namespace '$ns' have proper resource limits and requests."
            rm -f "$ns_dir/missing_resources.txt"
        fi
    done
}

# Generate summary
generate_summary() {
    echo -e "${CYAN}Generating summary report...${NC}"
    local summary_file="$OUTPUT_DIR/summary_report.txt"
    {
        echo "Summary Report - KubeDumper"
        echo "=========================="
        echo "Namespaces scanned: $(get_namespaces)"
        echo "Results saved to: $OUTPUT_DIR"
    } > "$summary_file"
    echo -e "${GREEN}Summary report saved to $summary_file.${NC}"
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n) NAMESPACE="$2"; shift ;;
        -o) OUTPUT_DIR="$2"; shift ;;
        --format) OUTPUT_FORMAT="$2"; shift ;;
        --check-secrets) execute_check "check_exposed_secrets" ;;
        --check-env-vars) execute_check "check_env_variables" ;;
        --check-privileged) execute_check "check_privileged_pods" ;;
        --check-api-access) execute_check "check_api_access" ;;
        --check-ingress) execute_check "check_ingress" ;;
        --check-rbac) execute_check "check_rbac" ;;
        --check-labels) execute_check "check_labels" ;;
        --check-failed-pods) execute_check "check_failed_pods" ;;
        --check-resources) execute_check "check_resources" ;;
        --all-checks) ALL_CHECKS=true ;;
        --dry-run) DRY_RUN=true ;;
        --verbose) VERBOSE=true ;;
        --meta) execute_check "collect_meta_artifacts_real" ;;
        -h|--help) display_help ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; display_help ;;
    esac
    shift
done

# Prepare the output directory
prepare_output_directory

# Run all checks if selected
if $ALL_CHECKS; then
    execute_check "collect_meta_artifacts_real"
    execute_check "check_exposed_secrets"
    execute_check "check_env_variables"
    execute_check "check_privileged_pods"
    execute_check "check_api_access"
    execute_check "check_ingress"
    execute_check "check_rbac"
    execute_check "check_labels"
    execute_check "check_failed_pods"
    execute_check "check_resources"
    generate_summary
fi

echo -e "${GREEN}Audit completed. Results are saved to $OUTPUT_DIR.${NC}"
