#!/bin/bash

# Default output directory for storing audit results
OUTPUT_DIR="./k8s_audit_results"
NAMESPACE="all" # Default to all namespaces
OUTPUT_FORMAT="text" # Default output format
ALL_CHECKS=false
DRY_RUN="false"   # Use string for DRY_RUN
VERBOSE="false"   # Use string for VERBOSE
THREADS=1 # Default single-threaded
META_REQUESTED=false # Track if meta was explicitly requested

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

display_help() {
    echo -e "${CYAN}KubeDumper - Kubernetes Security Audit Tool${NC}"
    echo
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -n <namespace(s)>      Specify one or more namespaces (comma-separated). Default: all."
    echo "  -o <output_dir>        Specify an output directory for results. Default: ./k8s_audit_results."
    echo "  --format <text|json|html> Specify output format (default: text)."
    echo "  --check-secrets        Check for exposed secrets."
    echo "  --check-env-vars       Check for sensitive environment variables."
    echo "  --check-privileged     Check for privileged/root pods."
    echo "  --check-api-access     Check for insecure API access."
    echo "  --check-ingress        Check for misconfigured ingress."
    echo "  --check-rbac           Check for RBAC misconfigurations."
    echo "  --check-labels         Check for missing labels (e.g. 'app' label)."
    echo "  --check-failed-pods    Check for failed pods."
    echo "  --check-resources      Check for missing resource requests/limits."
    echo "  --all-checks           Run all checks."
    echo "  --meta                 Collect meta artifacts about the cluster."
    echo "  --dry-run              Preview actions without executing."
    echo "  --verbose              Enable detailed logs."
    echo "  --threads <num>        Number of threads for parallel checks (default: 1)."
    echo "  -h, --help             Display this help menu."
    exit 0
}

log() {
    local message="$1"
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[LOG]${NC} $message"
        echo "[LOG] $message" >> kubeDumper.log
    fi
}

prepare_output_directory() {
    mkdir -p "$OUTPUT_DIR" || { echo -e "${RED}Error: Failed to create output directory: $OUTPUT_DIR${NC}"; exit 1; }
    log "Output directory prepared at $OUTPUT_DIR."
}

get_namespaces() {
    if [[ "$NAMESPACE" == "all" ]]; then
        kubectl get namespaces -o jsonpath="{.items[*].metadata.name}" 2>/dev/null || echo -e "${RED}Error retrieving namespaces.${NC}"
    else
        echo "$NAMESPACE" | tr ',' ' '
    fi
}

execute_check() {
    local check_function="$1"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY-RUN] Would execute: $check_function${NC}"
        log "[DRY-RUN] Skipped: $check_function"
    else
        $check_function
    fi
}

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

check_exposed_secrets() {
    echo -e "${CYAN}Checking for exposed secrets...${NC}"
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        ns_dir="$OUTPUT_DIR/$ns/exposed_secrets"
        mkdir -p "$ns_dir"

        secrets=$(kubectl get secrets -n "$ns" -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)
        for secret in $secrets; do
            secret_file="$ns_dir/$secret.txt"
            kubectl get secret "$secret" -n "$ns" -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' > "$secret_file" 2>/dev/null
            if [[ -s "$secret_file" ]]; then
                echo -e "${YELLOW}    Secret '$secret' in namespace '$ns' has exposed data: saved to $secret_file${NC}"
            else
                rm -f "$secret_file"
                echo -e "${CYAN}    Secret '$secret' in namespace '$ns' has no decodable data.${NC}"
            fi
        done
    done
}

check_env_variables() {
    echo -e "${CYAN}Checking for sensitive environment variables...${NC}"
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        ns_dir="$OUTPUT_DIR/$ns/env_variables"
        mkdir -p "$ns_dir"

        pods=$(kubectl get pods -n "$ns" -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)
        for pod in $pods; do
            pod_file="$ns_dir/$pod.txt"
            kubectl get pod "$pod" -n "$ns" -o json | jq -r '
                .spec.containers[].env[]? | "\(.name): \(.value // "ValueFrom: " + (.valueFrom | tostring))"
            ' > "$pod_file" 2>/dev/null
            if [[ -s "$pod_file" ]]; then
                echo -e "${YELLOW}    Environment variables for pod '$pod' stored in $pod_file${NC}"
            else
                rm -f "$pod_file"
                echo -e "${CYAN}    No sensitive environment variables found for pod '$pod'.${NC}"
            fi
        done
    done
}

check_privileged_pods() {
    echo -e "${CYAN}Checking for privileged/root pods...${NC}"
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        ns_dir="$OUTPUT_DIR/$ns/privileged_pods"
        mkdir -p "$ns_dir"

        pods=$(kubectl get pods -n "$ns" -o json)
        echo "$pods" | jq -r '
            .items[] |
            select(.spec.containers[].securityContext.privileged == true or .spec.containers[].securityContext.runAsUser == 0) |
            .metadata.name
        ' > "$ns_dir/privileged_pods.txt"

        if [[ -s "$ns_dir/privileged_pods.txt" ]]; then
            echo -e "${YELLOW}    Privileged/root pods found in namespace '$ns'. Results in $ns_dir/privileged_pods.txt${NC}"
        else
            echo -e "${CYAN}    No privileged/root pods in namespace '$ns'.${NC}"
            rm -f "$ns_dir/privileged_pods.txt"
        fi
    done
}

check_api_access() {
    echo -e "${CYAN}Checking API access for anonymous user...${NC}"
    local api_dir="$OUTPUT_DIR/api_access"
    mkdir -p "$api_dir"

    kubectl auth can-i '*' '*' --as=system:anonymous > "$api_dir/insecure_api_access.txt" 2>/dev/null
    if grep -q "yes" "$api_dir/insecure_api_access.txt"; then
        echo -e "${YELLOW}    Anonymous user has broad permissions. Results in $api_dir/insecure_api_access.txt${NC}"
    else
        echo -e "${GREEN}    Anonymous access is restricted.${NC}"
    fi
}

check_ingress() {
    echo -e "${CYAN}Checking ingress configurations...${NC}"
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        ns_dir="$OUTPUT_DIR/$ns/ingress"
        mkdir -p "$ns_dir"
        kubectl get ingress -n "$ns" -o json | jq -r '
            .items[] | select(.spec.tls == null) | "\(.metadata.name) missing HTTPS configuration"
        ' > "$ns_dir/insecure_ingress.txt"

        if [[ -s "$ns_dir/insecure_ingress.txt" ]]; then
            echo -e "${YELLOW}    Insecure ingress(es) found in namespace '$ns'. See $ns_dir/insecure_ingress.txt${NC}"
        else
            echo -e "${CYAN}    All ingress in namespace '$ns' have TLS configured or no ingress present.${NC}"
            rm -f "$ns_dir/insecure_ingress.txt"
        fi
    done
}

check_rbac() {
    echo -e "${CYAN}Checking RBAC configurations...${NC}"
    rbac_dir="$OUTPUT_DIR/rbac"
    mkdir -p "$rbac_dir"

    kubectl get roles,rolebindings,clusterroles,clusterrolebindings -A -o json > "$rbac_dir/rbac.json" 2>/dev/null
    if [[ -s "$rbac_dir/rbac.json" ]]; then
        jq -r '
            .items[] |
            select(.rules?[]?.resources? | index("*")) |
            "Overly permissive role: \(.metadata.name) in namespace \(.metadata.namespace // "cluster-scope")"
        ' "$rbac_dir/rbac.json" > "$rbac_dir/rbac_misconfigurations.txt"
        echo -e "${YELLOW}    RBAC details saved to $rbac_dir. Misconfigurations in rbac_misconfigurations.txt if any.${NC}"
    else
        echo -e "${CYAN}    No RBAC data retrieved.${NC}"
    fi
}

check_labels() {
    echo -e "${CYAN}Checking for missing 'app' labels...${NC}"
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        ns_dir="$OUTPUT_DIR/$ns/labels"
        mkdir -p "$ns_dir"
        kubectl get pods -n "$ns" -o json | jq -r '
            .items[] |
            select(.metadata.labels.app == null) |
            "Pod \(.metadata.name) is missing app label"
        ' > "$ns_dir/missing_labels.txt"

        if [[ -s "$ns_dir/missing_labels.txt" ]]; then
            echo -e "${YELLOW}    Pods missing 'app' label in namespace '$ns'. See $ns_dir/missing_labels.txt${NC}"
        else
            echo -e "${CYAN}    All pods in namespace '$ns' have 'app' labels or no pods present.${NC}"
            rm -f "$ns_dir/missing_labels.txt"
        fi
    done
}

check_failed_pods() {
    echo -e "${CYAN}Checking for failed pods...${NC}"
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        ns_dir="$OUTPUT_DIR/$ns/failed_pods"
        mkdir -p "$ns_dir"
        kubectl get pods -n "$ns" --field-selector=status.phase=Failed -o json > "$ns_dir/failed_pods.json" 2>/dev/null

        if [[ -s "$ns_dir/failed_pods.json" ]]; then
            echo -e "${YELLOW}    Failed pods found in namespace '$ns'. Details in $ns_dir/failed_pods.json${NC}"
        else
            echo -e "${CYAN}    No failed pods in namespace '$ns'.${NC}"
            rm -f "$ns_dir/failed_pods.json"
        fi
    done
}

check_resources() {
    echo -e "${CYAN}Checking for missing resource limits and requests...${NC}"
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        ns_dir="$OUTPUT_DIR/$ns/resources"
        mkdir -p "$ns_dir"

        kubectl get pods -n "$ns" -o json | jq -r '
            .items[] |
            select(.spec.containers[]? | (.resources.requests == null or .resources.limits == null)) |
            "Pod \(.metadata.name) is missing resource requests or limits"
        ' > "$ns_dir/missing_resources.txt" 2>/dev/null

        if [[ -s "$ns_dir/missing_resources.txt" ]]; then
            echo -e "${YELLOW}    Pods missing resource limits/requests in namespace '$ns'. See $ns_dir/missing_resources.txt${NC}"
        else
            echo -e "${CYAN}    All pods in namespace '$ns' have proper resource limits and requests.${NC}"
            rm -f "$ns_dir/missing_resources.txt"
        fi
    done
}

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
        --dry-run) DRY_RUN="true" ;;
        --verbose) VERBOSE="true" ;;
        --threads) THREADS="$2"; shift ;;
        --meta) META_REQUESTED=true; execute_check "collect_meta_artifacts_real" ;;
        -h|--help) display_help ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; display_help ;;
    esac
    shift
done

export NAMESPACE OUTPUT_DIR OUTPUT_FORMAT ALL_CHECKS DRY_RUN VERBOSE THREADS

prepare_output_directory

# Export functions so they can be used by parallel
export -f execute_check
export -f collect_meta_artifacts_real
export -f check_exposed_secrets
export -f check_env_variables
export -f check_privileged_pods
export -f check_api_access
export -f check_ingress
export -f check_rbac
export -f check_labels
export -f check_failed_pods
export -f check_resources

if [ "$ALL_CHECKS" = "true" ]; then
    # If user didn't request meta separately but wants all checks, run meta now, once, before parallel checks
    if [ "$META_REQUESTED" = "false" ]; then
        execute_check "collect_meta_artifacts_real"
    fi

    # Only the parallelizable checks (excluding meta)
    CHECKS=(
        "check_exposed_secrets"
        "check_env_variables"
        "check_privileged_pods"
        "check_api_access"
        "check_ingress"
        "check_rbac"
        "check_labels"
        "check_failed_pods"
        "check_resources"
    )

    if [ "$THREADS" -gt 1 ]; then
        if command -v parallel &>/dev/null; then
            echo -e "${CYAN}Running all checks with $THREADS threads...${NC}"
            printf '%s\n' "${CHECKS[@]}" | parallel -j "$THREADS" execute_check {}
        else
            echo -e "${YELLOW}GNU parallel not found. Running checks sequentially.${NC}"
            for c in "${CHECKS[@]}"; do
                execute_check "$c"
            done
        fi
    else
        for c in "${CHECKS[@]}"; do
            execute_check "$c"
        done
    fi

    generate_summary
fi

echo -e "${GREEN}Audit completed. Results are saved to $OUTPUT_DIR.${NC}"
