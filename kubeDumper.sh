#!/bin/bash

# ================================
# KubeDumper - Kubernetes Security Audit Tool
# ================================

# Default configuration
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

# ================================
# Function Definitions
# ================================

# Display help menu
display_help() {
    echo -e "${CYAN}KubeDumper - Kubernetes Security Audit Tool${NC}"
    echo
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -n <namespace(s)>             Specify one or more namespaces (comma-separated). Default: all."
    echo "  -o <output_dir>               Specify an output directory for results. Default: ./k8s_audit_results."
    echo "  --format <text|json|html>     Specify output format (default: text)."
    echo "  --check-secrets               Check for exposed secrets."
    echo "  --check-env-vars              Check for sensitive environment variables."
    echo "  --check-privileged            Check for privileged/root pods."
    echo "  --check-api-access            Check for insecure API access."
    echo "  --check-ingress               Check for misconfigured ingress."
    echo "  --check-rbac                  Check for RBAC misconfigurations."
    echo "  --check-labels                Check for missing labels (e.g. 'app' label)."
    echo "  --check-failed-pods           Check for failed pods."
    echo "  --check-resources             Check for missing resource requests/limits."
    echo "  --download-manifests          Download all Kubernetes manifests to the output directory."
    echo "  --all-checks                  Run all checks."
    echo "  --meta                        Collect meta artifacts about the cluster."
    echo "  --dry-run                     Preview actions without executing."
    echo "  --verbose                     Enable detailed logs."
    echo "  --threads <num>               Number of threads for parallel checks (default: 1)."
    echo "  -h, --help                    Display this help menu."
    exit 0
}

# Logging function
log() {
    local message="$1"
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[LOG]${NC} $message"
    fi
    echo "[LOG] $(date '+%Y-%m-%d %H:%M:%S') $message" >> "$OUTPUT_DIR/kubeDumper.log"
}

# Prepare output directory
prepare_output_directory() {
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY-RUN] Would create output directory at $OUTPUT_DIR${NC}"
        log "[DRY-RUN] Skipped creating output directory at $OUTPUT_DIR."
    else
        mkdir -p "$OUTPUT_DIR" || { echo -e "${RED}Error: Failed to create output directory: $OUTPUT_DIR${NC}"; exit 1; }
        log "Output directory prepared at $OUTPUT_DIR."
    fi
}

# Get namespaces to scan
get_namespaces() {
    if [[ "$NAMESPACE" == "all" ]]; then
        local namespaces
        namespaces=$(kubectl get namespaces -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)
        if [[ $? -ne 0 || -z "$namespaces" ]]; then
            echo -e "${RED}Error: Failed to retrieve namespaces.${NC}"
            exit 1
        fi
        echo "$namespaces"
    else
        echo "$NAMESPACE" | tr ',' ' '
    fi
}

# Execute a check function with DRY_RUN consideration
execute_check() {
    local check_function="$1"
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY-RUN] Would execute: $check_function${NC}"
        log "[DRY-RUN] Skipped: $check_function"
    else
        "$check_function"
    fi
}

# Download Kubernetes manifests
download_manifests() {
    echo -e "${CYAN}Downloading all Kubernetes manifests...${NC}"
    log "Starting download_manifests."
    local manifest_dir="$OUTPUT_DIR/manifests"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY-RUN] Would create manifest directory at $manifest_dir and download manifests.${NC}"
        log "[DRY-RUN] Skipped downloading manifests."
        return
    fi

    mkdir -p "$manifest_dir" || { echo -e "${RED}Error: Failed to create manifest directory: $manifest_dir${NC}"; return; }

    # Define resources to fetch
    local resources=("pods" "services" "deployments" "statefulsets" "daemonsets" "replicasets" "configmaps" "secrets" "ingress")
    for resource in "${resources[@]}"; do
        echo -e "${CYAN}Fetching $resource manifests...${NC}"
        log "Fetching $resource manifests."
        for ns in $(get_namespaces); do
            local ns_dir="$manifest_dir/$ns"
            mkdir -p "$ns_dir" || { echo -e "${RED}Error: Failed to create namespace directory: $ns_dir${NC}"; continue; }
            if kubectl get "$resource" -n "$ns" -o yaml > "$ns_dir/$resource.yaml" 2>/dev/null; then
                if [[ -s "$ns_dir/$resource.yaml" ]]; then
                    echo -e "${GREEN}  $resource manifests saved for namespace '$ns'.${NC}"
                    log "Saved $resource manifests for namespace '$ns'."
                else
                    rm -f "$ns_dir/$resource.yaml"
                    echo -e "${YELLOW}  No $resource found in namespace '$ns'.${NC}"
                    log "No $resource found in namespace '$ns'."
                fi
            else
                echo -e "${RED}  Failed to fetch $resource for namespace '$ns'.${NC}"
                log "Failed to fetch $resource for namespace '$ns'."
            fi
        done
    done

    echo -e "${GREEN}All manifests downloaded and saved to $manifest_dir.${NC}"
    log "Completed download_manifests."
}

# Collect meta artifacts
collect_meta_artifacts_real() {
    echo -e "${CYAN}Collecting meta artifacts...${NC}"
    log "Starting collect_meta_artifacts_real."
    local meta_dir="$OUTPUT_DIR/meta"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY-RUN] Would create meta directory at $meta_dir and collect meta artifacts.${NC}"
        log "[DRY-RUN] Skipped collecting meta artifacts."
        return
    fi

    mkdir -p "$meta_dir" || { echo -e "${RED}Error: Failed to create meta directory: $meta_dir${NC}"; return; }

    # Collect various cluster information
    local commands=(
        "kubectl cluster-info > \"$meta_dir/cluster_info.txt\""
        "kubectl get nodes -o wide > \"$meta_dir/nodes.txt\""
        "kubectl get namespaces > \"$meta_dir/namespaces.txt\""
        "kubectl api-resources > \"$meta_dir/api_resources.txt\""
        "kubectl version > \"$meta_dir/version.txt\""
        "kubectl config view > \"$meta_dir/config_context.txt\""
    )

    for cmd in "${commands[@]}"; do
        eval "$cmd" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}  Failed to execute: $cmd${NC}"
            log "Failed to execute: $cmd"
        else
            echo -e "${GREEN}  Executed: $cmd${NC}"
            log "Executed: $cmd"
        fi
    done

    echo -e "${GREEN}Meta artifacts collected in $meta_dir.${NC}"
    log "Completed collect_meta_artifacts_real."
}

# Check for exposed secrets
check_exposed_secrets() {
    echo -e "${CYAN}Checking for exposed secrets...${NC}"
    log "Starting check_exposed_secrets."
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        log "Scanning secrets in namespace '$ns'."
        local ns_dir="$OUTPUT_DIR/$ns/exposed_secrets"

        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would create directory $ns_dir and check secrets.${NC}"
            log "[DRY-RUN] Skipped checking secrets in namespace '$ns'."
            continue
        fi

        mkdir -p "$ns_dir" || { echo -e "${RED}Error: Failed to create directory $ns_dir${NC}"; continue; }

        secrets=$(kubectl get secrets -n "$ns" -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)
        if [[ $? -ne 0 || -z "$secrets" ]]; then
            echo -e "${YELLOW}    No secrets found or failed to retrieve secrets in namespace '$ns'.${NC}"
            log "No secrets found or failed to retrieve secrets in namespace '$ns'."
            continue
        fi

        for secret in $secrets; do
            local secret_file="$ns_dir/$secret.txt"
            if kubectl get secret "$secret" -n "$ns" -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' > "$secret_file" 2>/dev/null; then
                if [[ -s "$secret_file" ]]; then
                    echo -e "${YELLOW}    Secret '$secret' in namespace '$ns' has exposed data: saved to $secret_file${NC}"
                    log "Secret '$secret' in namespace '$ns' has exposed data."
                else
                    rm -f "$secret_file"
                    echo -e "${CYAN}    Secret '$secret' in namespace '$ns' has no decodable data.${NC}"
                    log "Secret '$secret' in namespace '$ns' has no decodable data."
                fi
            else
                echo -e "${RED}    Error: Failed to process secret '$secret' in namespace '$ns'.${NC}"
                log "Failed to process secret '$secret' in namespace '$ns'."
                rm -f "$secret_file"
            fi
        done
    done
    log "Completed check_exposed_secrets."
}

# Check for sensitive environment variables
check_env_variables() {
    echo -e "${CYAN}Checking for sensitive environment variables...${NC}"
    log "Starting check_env_variables."
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        log "Scanning environment variables in namespace '$ns'."
        local ns_dir="$OUTPUT_DIR/$ns/env_variables"

        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would create directory $ns_dir and check environment variables.${NC}"
            log "[DRY-RUN] Skipped checking environment variables in namespace '$ns'."
            continue
        fi

        mkdir -p "$ns_dir" || { echo -e "${RED}Error: Failed to create directory $ns_dir${NC}"; continue; }

        pods=$(kubectl get pods -n "$ns" -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)
        if [[ $? -ne 0 || -z "$pods" ]]; then
            echo -e "${YELLOW}    No pods found or failed to retrieve pods in namespace '$ns'.${NC}"
            log "No pods found or failed to retrieve pods in namespace '$ns'."
            continue
        fi

        for pod in $pods; do
            local pod_file="$ns_dir/$pod.txt"
            if kubectl get pod "$pod" -n "$ns" -o json | jq -r '
                .spec.containers[].env[]? | select(.name | test("^(PASSWORD|SECRET|TOKEN|KEY)$")) | "\(.name): \(.value // ("ValueFrom: " + (.valueFrom | tostring)))"
            ' > "$pod_file" 2>/dev/null; then
                if [[ -s "$pod_file" ]]; then
                    echo -e "${YELLOW}    Environment variables for pod '$pod' stored in $pod_file${NC}"
                    log "Environment variables for pod '$pod' in namespace '$ns' stored."
                else
                    rm -f "$pod_file"
                    echo -e "${CYAN}    No sensitive environment variables found for pod '$pod'.${NC}"
                    log "No sensitive environment variables found for pod '$pod' in namespace '$ns'."
                fi
            else
                echo -e "${RED}    Error: Failed to retrieve environment variables for pod '$pod' in namespace '$ns'.${NC}"
                log "Failed to retrieve environment variables for pod '$pod' in namespace '$ns'."
                rm -f "$pod_file"
            fi
        done
    done
    log "Completed check_env_variables."
}

# Check for privileged or root pods
check_privileged_pods() {
    echo -e "${CYAN}Checking for privileged/root pods...${NC}"
    log "Starting check_privileged_pods."
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        log "Scanning privileged pods in namespace '$ns'."
        local ns_dir="$OUTPUT_DIR/$ns/privileged_pods"

        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would create directory $ns_dir and check privileged pods.${NC}"
            log "[DRY-RUN] Skipped checking privileged pods in namespace '$ns'."
            continue
        fi

        mkdir -p "$ns_dir" || { echo -e "${RED}Error: Failed to create directory $ns_dir${NC}"; continue; }

        pods=$(kubectl get pods -n "$ns" -o json 2>/dev/null)
        if [[ $? -ne 0 || -z "$pods" ]]; then
            echo -e "${YELLOW}    No pods found or failed to retrieve pods in namespace '$ns'.${NC}"
            log "No pods found or failed to retrieve pods in namespace '$ns'."
            continue
        fi

        echo "$pods" | jq -r '
            .items[] |
            select(
                (.spec.containers[].securityContext.privileged == true) or
                (.spec.containers[].securityContext.runAsUser == 0)
            ) |
            .metadata.name
        ' > "$ns_dir/privileged_pods.txt" 2>/dev/null

        if [[ -s "$ns_dir/privileged_pods.txt" ]]; then
            echo -e "${YELLOW}    Privileged/root pods found in namespace '$ns'. Results in $ns_dir/privileged_pods.txt${NC}"
            log "Privileged/root pods found in namespace '$ns'."
        else
            echo -e "${CYAN}    No privileged/root pods in namespace '$ns'.${NC}"
            log "No privileged/root pods found in namespace '$ns'."
            rm -f "$ns_dir/privileged_pods.txt"
        fi
    done
    log "Completed check_privileged_pods."
}

# Check for insecure API access
check_api_access() {
    echo -e "${CYAN}Checking API access for anonymous user...${NC}"
    log "Starting check_api_access."
    local api_dir="$OUTPUT_DIR/api_access"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY-RUN] Would create directory $api_dir and check API access.${NC}"
        log "[DRY-RUN] Skipped checking API access."
        return
    fi

    mkdir -p "$api_dir" || { echo -e "${RED}Error: Failed to create directory $api_dir${NC}"; return; }

    if kubectl auth can-i '*' '*' --as=system:anonymous > "$api_dir/insecure_api_access.txt" 2>/dev/null; then
        if grep -q "yes" "$api_dir/insecure_api_access.txt"; then
            echo -e "${YELLOW}    Anonymous user has broad permissions. Results in $api_dir/insecure_api_access.txt${NC}"
            log "Anonymous user has broad API permissions."
        else
            echo -e "${GREEN}    Anonymous access is restricted.${NC}"
            log "Anonymous access is restricted."
            rm -f "$api_dir/insecure_api_access.txt"
        fi
    else
        echo -e "${RED}    Error: Failed to check API access.${NC}"
        log "Failed to check API access."
        rm -f "$api_dir/insecure_api_access.txt"
    fi
    log "Completed check_api_access."
}

# Check ingress configurations
check_ingress() {
    echo -e "${CYAN}Checking ingress configurations...${NC}"
    log "Starting check_ingress."
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        log "Scanning ingress configurations in namespace '$ns'."
        local ns_dir="$OUTPUT_DIR/$ns/ingress"

        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would create directory $ns_dir and check ingress configurations.${NC}"
            log "[DRY-RUN] Skipped checking ingress configurations in namespace '$ns'."
            continue
        fi

        mkdir -p "$ns_dir" || { echo -e "${RED}Error: Failed to create directory $ns_dir${NC}"; continue; }

        if kubectl get ingress -n "$ns" -o json | jq -r '
            .items[] | select(.spec.tls == null) | "\(.metadata.name) missing HTTPS configuration"
        ' > "$ns_dir/insecure_ingress.txt" 2>/dev/null; then
            if [[ -s "$ns_dir/insecure_ingress.txt" ]]; then
                echo -e "${YELLOW}    Insecure ingress(es) found in namespace '$ns'. See $ns_dir/insecure_ingress.txt${NC}"
                log "Insecure ingress(es) found in namespace '$ns'."
            else
                echo -e "${CYAN}    All ingress in namespace '$ns' have TLS configured or no ingress present.${NC}"
                log "All ingress in namespace '$ns' have TLS or none present."
                rm -f "$ns_dir/insecure_ingress.txt"
            fi
        else
            echo -e "${RED}    Error: Failed to retrieve ingress configurations for namespace '$ns'.${NC}"
            log "Failed to retrieve ingress configurations for namespace '$ns'."
            rm -f "$ns_dir/insecure_ingress.txt"
        fi
    done
    log "Completed check_ingress."
}

# Check RBAC configurations
check_rbac() {
    echo -e "${CYAN}Checking RBAC configurations...${NC}"
    log "Starting check_rbac."
    local rbac_dir="$OUTPUT_DIR/rbac"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY-RUN] Would create directory $rbac_dir and check RBAC configurations.${NC}"
        log "[DRY-RUN] Skipped checking RBAC configurations."
        return
    fi

    mkdir -p "$rbac_dir" || { echo -e "${RED}Error: Failed to create directory $rbac_dir${NC}"; return; }

    if kubectl get roles,rolebindings,clusterroles,clusterrolebindings -A -o json > "$rbac_dir/rbac.json" 2>/dev/null; then
        if [[ -s "$rbac_dir/rbac.json" ]]; then
            jq -r '
                .items[] |
                select(.rules?[]?.resources? | index("*")) |
                "Overly permissive role: \(.metadata.name) in namespace \(.metadata.namespace // "cluster-scope")"
            ' "$rbac_dir/rbac.json" > "$rbac_dir/rbac_misconfigurations.txt" 2>/dev/null

            if [[ -s "$rbac_dir/rbac_misconfigurations.txt" ]]; then
                echo -e "${YELLOW}    RBAC misconfigurations found. See $rbac_dir/rbac_misconfigurations.txt${NC}"
                log "RBAC misconfigurations found."
            else
                echo -e "${GREEN}    No RBAC misconfigurations detected.${NC}"
                log "No RBAC misconfigurations detected."
                rm -f "$rbac_dir/rbac_misconfigurations.txt"
            fi
        else
            echo -e "${YELLOW}    No RBAC data retrieved.${NC}"
            log "No RBAC data retrieved."
        fi
    else
        echo -e "${RED}    Error: Failed to retrieve RBAC configurations.${NC}"
        log "Failed to retrieve RBAC configurations."
    fi
    log "Completed check_rbac."
}

# Check for missing 'app' labels
check_labels() {
    echo -e "${CYAN}Checking for missing 'app' labels...${NC}"
    log "Starting check_labels."
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        log "Scanning labels in namespace '$ns'."
        local ns_dir="$OUTPUT_DIR/$ns/labels"

        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would create directory $ns_dir and check for missing 'app' labels.${NC}"
            log "[DRY-RUN] Skipped checking labels in namespace '$ns'."
            continue
        fi

        mkdir -p "$ns_dir" || { echo -e "${RED}Error: Failed to create directory $ns_dir${NC}"; continue; }

        if kubectl get pods -n "$ns" -o json | jq -r '
            .items[] |
            select(.metadata.labels.app == null) |
            "Pod \(.metadata.name) is missing app label"
        ' > "$ns_dir/missing_labels.txt" 2>/dev/null; then
            if [[ -s "$ns_dir/missing_labels.txt" ]]; then
                echo -e "${YELLOW}    Pods missing 'app' label in namespace '$ns'. See $ns_dir/missing_labels.txt${NC}"
                log "Pods missing 'app' label found in namespace '$ns'."
            else
                echo -e "${CYAN}    All pods in namespace '$ns' have 'app' labels or no pods present.${NC}"
                log "All pods in namespace '$ns' have 'app' labels or no pods present."
                rm -f "$ns_dir/missing_labels.txt"
            fi
        else
            echo -e "${RED}    Error: Failed to retrieve pods or check labels in namespace '$ns'.${NC}"
            log "Failed to retrieve pods or check labels in namespace '$ns'."
            rm -f "$ns_dir/missing_labels.txt"
        fi
    done
    log "Completed check_labels."
}

# Check for failed pods
check_failed_pods() {
    echo -e "${CYAN}Checking for failed pods...${NC}"
    log "Starting check_failed_pods."
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        log "Scanning failed pods in namespace '$ns'."
        local ns_dir="$OUTPUT_DIR/$ns/failed_pods"

        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would create directory $ns_dir and check for failed pods.${NC}"
            log "[DRY-RUN] Skipped checking failed pods in namespace '$ns'."
            continue
        fi

        mkdir -p "$ns_dir" || { echo -e "${RED}Error: Failed to create directory $ns_dir${NC}"; continue; }

        if kubectl get pods -n "$ns" --field-selector=status.phase=Failed -o json > "$ns_dir/failed_pods.json" 2>/dev/null; then
            if [[ -s "$ns_dir/failed_pods.json" ]]; then
                echo -e "${YELLOW}    Failed pods found in namespace '$ns'. Details in $ns_dir/failed_pods.json${NC}"
                log "Failed pods found in namespace '$ns'."
            else
                echo -e "${CYAN}    No failed pods in namespace '$ns'.${NC}"
                log "No failed pods in namespace '$ns'."
                rm -f "$ns_dir/failed_pods.json"
            fi
        else
            echo -e "${RED}    Error: Failed to retrieve pods for namespace '$ns'.${NC}"
            log "Failed to retrieve pods for namespace '$ns'."
            rm -f "$ns_dir/failed_pods.json"
        fi
    done
    log "Completed check_failed_pods."
}

# Check for missing resource limits and requests
check_resources() {
    echo -e "${CYAN}Checking for missing resource limits and requests...${NC}"
    log "Starting check_resources."
    for ns in $(get_namespaces); do
        echo -e "${CYAN}  Namespace: $ns${NC}"
        log "Scanning resource limits in namespace '$ns'."
        local ns_dir="$OUTPUT_DIR/$ns/resources"

        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}[DRY-RUN] Would create directory $ns_dir and check resource limits.${NC}"
            log "[DRY-RUN] Skipped checking resource limits in namespace '$ns'."
            continue
        fi

        mkdir -p "$ns_dir" || { echo -e "${RED}Error: Failed to create directory $ns_dir${NC}"; continue; }

        if kubectl get pods -n "$ns" -o json | jq -r '
            .items[] |
            select(
                (.spec.containers[]?.resources.requests == null) or
                (.spec.containers[]?.resources.limits == null)
            ) |
            "Pod \(.metadata.name) is missing resource requests or limits"
        ' > "$ns_dir/missing_resources.txt" 2>/dev/null; then
            if [[ -s "$ns_dir/missing_resources.txt" ]]; then
                echo -e "${YELLOW}    Pods missing resource limits/requests in namespace '$ns'. See $ns_dir/missing_resources.txt${NC}"
                log "Pods missing resource limits/requests found in namespace '$ns'."
            else
                echo -e "${CYAN}    All pods in namespace '$ns' have proper resource limits and requests.${NC}"
                log "All pods in namespace '$ns' have proper resource limits and requests."
                rm -f "$ns_dir/missing_resources.txt"
            fi
        else
            echo -e "${RED}    Error: Failed to retrieve pods or check resources in namespace '$ns'.${NC}"
            log "Failed to retrieve pods or check resources in namespace '$ns'."
            rm -f "$ns_dir/missing_resources.txt"
        fi
    done
    log "Completed check_resources."
}

# Generate summary report
generate_summary() {
    echo -e "${CYAN}Generating summary report...${NC}"
    log "Starting generate_summary."
    local summary_file="$OUTPUT_DIR/summary_report.$OUTPUT_FORMAT"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY-RUN] Would generate summary report at $summary_file.${NC}"
        log "[DRY-RUN] Skipped generating summary report."
        return
    fi

    case "$OUTPUT_FORMAT" in
        json)
            jq -n \
                --arg timestamp "$(date '+%Y-%m-%d %H:%M:%S')" \
                --arg namespaces "$(get_namespaces | tr ' ' ',')" \
                --arg output_dir "$OUTPUT_DIR" \
                '{
                    summary: {
                        timestamp: $timestamp,
                        namespaces_scanned: $namespaces,
                        results_saved_to: $output_dir
                    }
                }' > "$summary_file"
            ;;
        html)
            {
                echo "<html><head><title>Summary Report - KubeDumper</title></head><body>"
                echo "<h1>Summary Report - KubeDumper</h1>"
                echo "<p><strong>Timestamp:</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>"
                echo "<p><strong>Namespaces Scanned:</strong> $(get_namespaces)</p>"
                echo "<p><strong>Results Saved To:</strong> $OUTPUT_DIR</p>"
                echo "</body></html>"
            } > "$summary_file"
            ;;
        *)
            # Default to text
            {
                echo "Summary Report - KubeDumper"
                echo "=========================="
                echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "Namespaces scanned: $(get_namespaces)"
                echo "Results saved to: $OUTPUT_DIR"
            } > "$summary_file"
            ;;
    esac

    echo -e "${GREEN}Summary report saved to $summary_file.${NC}"
    log "Summary report generated at $summary_file."
    log "Completed generate_summary."
}

# ================================
# Dependency Checks
# ================================

check_dependencies() {
    echo -e "${CYAN}Checking for required commands...${NC}"
    log "Starting dependency checks."
    local dependencies=("kubectl" "jq")
    local missing=()

    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ "${#missing[@]}" -ne 0 ]; then
        echo -e "${RED}Error: The following required commands are missing: ${missing[*]}${NC}"
        log "Missing dependencies: ${missing[*]}"
        exit 1
    fi

    if [ "$THREADS" -gt 1 ] && ! command -v parallel &>/dev/null; then
        echo -e "${YELLOW}Warning: GNU parallel not found. Running checks sequentially.${NC}"
        log "GNU parallel not found. Setting THREADS to 1."
        THREADS=1
    fi

    echo -e "${GREEN}All required commands are available.${NC}"
    log "All required dependencies are satisfied."
}

# ================================
# Argument Parsing
# ================================

# Parse command-line arguments
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -n)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    NAMESPACE="$2"
                    shift
                else
                    echo -e "${RED}Error: -n requires a non-empty argument.${NC}"
                    exit 1
                fi
                ;;
            -o)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    OUTPUT_DIR="$2"
                    shift
                else
                    echo -e "${RED}Error: -o requires a non-empty argument.${NC}"
                    exit 1
                fi
                ;;
            --format)
                if [[ -n "$2" && "$2" =~ ^(text|json|html)$ ]]; then
                    OUTPUT_FORMAT="$2"
                    shift
                else
                    echo -e "${RED}Error: --format requires one of the following arguments: text, json, html.${NC}"
                    exit 1
                fi
                ;;
            --check-secrets) execute_check "check_exposed_secrets" ;;
            --check-env-vars) execute_check "check_env_variables" ;;
            --check-privileged) execute_check "check_privileged_pods" ;;
            --check-api-access) execute_check "check_api_access" ;;
            --check-ingress) execute_check "check_ingress" ;;
            --check-rbac) execute_check "check_rbac" ;;
            --check-labels) execute_check "check_labels" ;;
            --check-failed-pods) execute_check "check_failed_pods" ;;
            --check-resources) execute_check "check_resources" ;;
            --download-manifests) execute_check "download_manifests" ;;
            --all-checks) ALL_CHECKS=true ;;
            --meta)
                META_REQUESTED=true
                execute_check "collect_meta_artifacts_real"
                ;;
            --dry-run) DRY_RUN="true" ;;
            --verbose) VERBOSE="true" ;;
            --threads)
                if [[ -n "$2" && "$2" =~ ^[1-9][0-9]*$ ]]; then
                    THREADS="$2"
                    shift
                else
                    echo -e "${RED}Error: --threads requires a positive integer.${NC}"
                    exit 1
                fi
                ;;
            -h|--help) display_help ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                display_help
                ;;
        esac
        shift
    done
}

# ================================
# Main Execution
# ================================

# Start of the script
main() {
    # Parse arguments
    parse_arguments "$@"

    # Check dependencies
    check_dependencies

    # Export variables and functions for parallel execution
    export NAMESPACE OUTPUT_DIR OUTPUT_FORMAT ALL_CHECKS DRY_RUN VERBOSE THREADS
    export -f log
    export -f get_namespaces
    export -f execute_check
    export -f download_manifests
    export -f check_exposed_secrets
    export -f check_env_variables
    export -f check_privileged_pods
    export -f check_api_access
    export -f check_ingress
    export -f check_rbac
    export -f check_labels
    export -f check_failed_pods
    export -f check_resources
    export -f collect_meta_artifacts_real
    export -f generate_summary

    # Prepare output directory
    execute_check "prepare_output_directory"

    # Run all checks if requested
    if [ "$ALL_CHECKS" = "true" ]; then
        log "Starting all checks as --all-checks is enabled."
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
            "download_manifests"
        )

        if [ "$THREADS" -gt 1 ]; then
            if command -v parallel &>/dev/null; then
                echo -e "${CYAN}Running all checks with $THREADS threads...${NC}"
                log "Running all checks with $THREADS threads using GNU parallel."
                printf '%s\n' "${CHECKS[@]}" | parallel -j "$THREADS" execute_check {}
            else
                echo -e "${YELLOW}GNU parallel not found. Running checks sequentially.${NC}"
                log "GNU parallel not found. Running checks sequentially."
                for c in "${CHECKS[@]}"; do
                    execute_check "$c"
                done
            fi
        else
            for c in "${CHECKS[@]}"; do
                execute_check "$c"
            done
        fi
    fi

    # Generate summary report
    execute_check "generate_summary"

    echo -e "${GREEN}Audit completed. Results are saved to $OUTPUT_DIR.${NC}"
    log "Audit completed. Results are saved to $OUTPUT_DIR."
}

# Invoke main with all script arguments
main "$@"

