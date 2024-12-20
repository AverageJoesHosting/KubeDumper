#!/usr/bin/env bash

# ================================
# KubeDumper - Kubernetes Security Audit Tool
# ================================

# Set script to exit on any error
set -e

# ================================
# Load Configuration
# ================================

CONFIG_FILE="$(dirname "$0")/config/config.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Configuration file not found: $CONFIG_FILE${NC}" >&2
    exit 1
fi
source "$CONFIG_FILE"

# ================================
# Initialize Check Flags
# ================================
# These flags determine which checks to run based on user input
CHECK_SECRETS=false
CHECK_ENV_VARS=false
CHECK_PRIVILEGED=false
CHECK_API_ACCESS=false
CHECK_INGRESS=false
CHECK_EGRESS=false
CHECK_RBAC=false
CHECK_LABELS=false
CHECK_FAILED_PODS=false
CHECK_RESOURCES=false
CHECK_IMDS=false
CHECK_EXPOSED_API_ENDPOINTS=false
CHECK_HELM_TILLER=false
CHECK_KUBELET=false
CHECK_SECURITY_CONTEXT=false
CHECK_HOST_NETWORK=false
CHECK_HOSTPID=false
CHECK_HOST_PATH_MOUNT=false
CHECK_PSP=false
CHECK_PSA=false
CHECK_KUBE_BENCH=false
DOWNLOAD_MANIFESTS=false
KUBE_SCORE_ENABLED=false
CHECK_THIRD_PARTY_IMAGE=false
COLLECT_CUSTOM_RESOURCES=false

# Initialize default values
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/kubedumper-results}"
THREADS="${THREADS:-1}"

mkdir -p "$OUTPUT_DIR"

# ================================
# Load Utility Functions
# ================================

UTILS_FILE="$(dirname "$0")/modules/utils.sh"
if [[ ! -f "$UTILS_FILE" ]]; then
    echo "Utility functions file not found: $UTILS_FILE" >&2
    exit 1
fi
source "$UTILS_FILE"

# ================================
# Display Help Menu
# ================================

display_help() {
    echo -e "${CYAN}KubeDumper - Kubernetes Security Audit Tool${NC}"
    echo
    echo "Usage: $0 [options]"
    echo "Options:"
    echo -e "  ${CYAN}-n <namespace(s)>${NC}             Specify one or more namespaces (comma-separated). Default: all."
    echo -e "  ${CYAN}-o <output_dir>${NC}               Specify an output directory for results. Default: ${OUTPUT_DIR}."
    echo -e "  ${CYAN}--format <text|json|html>${NC}     Specify output format (default: ${OUTPUT_FORMAT})."
    echo -e "  ${CYAN}--check-secrets${NC}               Check for exposed secrets."
    echo -e "  ${CYAN}--check-env-vars${NC}              Check for sensitive environment variables."
    echo -e "  ${CYAN}--check-privileged${NC}            Check for privileged/root pods."
    echo -e "  ${CYAN}--check-api-access${NC}            Check for insecure API access."
    echo -e "  ${CYAN}--check-ingress${NC}               Check for misconfigured ingress."
    echo -e "  ${CYAN}--check-egress${NC}                Check for unrestricted egress configurations."
    echo -e "  ${CYAN}--check-rbac${NC}                  Check for RBAC misconfigurations."
    echo -e "  ${CYAN}--check-labels${NC}                Check for missing labels (e.g. 'app' label)."
    echo -e "  ${CYAN}--check-failed-pods${NC}           Check for failed pods."
    echo -e "  ${CYAN}--check-resources${NC}             Check for missing resource requests/limits."
    echo -e "  ${CYAN}--check-imds${NC}                  Check for IMDS vulnerabilities."
    echo -e "  ${CYAN}--check-exposed-api-endpoints${NC} Check for exposed API server endpoints."
    echo -e "  ${CYAN}--check-helm-tiller${NC}           Check for Helm Tiller components in the cluster."
    echo -e "  ${CYAN}--check-kubelet${NC}               Check for unauthorized kubelet access."
    echo -e "  ${CYAN}--check-security-context${NC}      Check for exploitable security contexts in pods."
    echo -e "  ${CYAN}--collect-cr${NC}                  Collect all custom resources (CRs) in the cluster."
    echo -e "  ${CYAN}--check-host-network${NC}          Check for pods using hostNetwork."
    echo -e "  ${CYAN}--check-hostpid${NC}               Check for exploitable HostPID settings."
    echo -e "  ${CYAN}--check-host-path-mount${NC}       Check if hostPath volume can be mounted."
    echo -e "  ${CYAN}--check-psp${NC}                   Check for Pod Security Policies (PSPs)."
    echo -e "  ${CYAN}--check-psa${NC}                   Check Pod Security Admission (PSA) configurations."
    echo -e "  ${CYAN}--check-kube-bench${NC}            Run kube-bench scan for CIS Kubernetes Benchmark."
    echo -e "  ${CYAN}--download-manifests${NC}          Download all Kubernetes manifests to the output directory."
    echo -e "  ${CYAN}--check-third-party-image${NC}     Check if a third-party image like nginx can be deployed."
    echo -e "  ${CYAN}--all-checks${NC}                  Run all checks."
    echo -e "  ${CYAN}--meta${NC}                        Collect meta artifacts about the cluster."
    echo -e "  ${CYAN}--dry-run${NC}                     Preview actions without executing."
    echo -e "  ${CYAN}--verbose${NC}                     Enable detailed logs."
    echo -e "  ${CYAN}--threads <num>${NC}               Number of threads for parallel checks (default: ${THREADS})."
    echo -e "  ${CYAN}-h, --help${NC}                    Display this help menu."
    exit 0
}

# ================================
# Argument Parsing Function
# ================================

parse_arguments_main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n)
                NAMESPACE=$2
                shift 2
                ;;
            -o)
                OUTPUT_DIR=$2
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT=$2
                shift 2
                ;;
            --check-secrets)
                CHECK_SECRETS=true
                shift
                ;;
            --check-env-vars)
                CHECK_ENV_VARS=true
                shift
                ;;
            --check-privileged)
                CHECK_PRIVILEGED=true
                shift
                ;;
            --check-api-access)
                CHECK_API_ACCESS=true
                shift
                ;;
            --check-ingress)
                CHECK_INGRESS=true
                shift
                ;;
            --check-egress)
                CHECK_EGRESS=true
                shift
                ;;
            --check-rbac)
                CHECK_RBAC=true
                shift
                ;;
            --check-labels)
                CHECK_LABELS=true
                shift
                ;;
            --check-failed-pods)
                CHECK_FAILED_PODS=true
                shift
                ;;
            --check-resources)
                CHECK_RESOURCES=true
                shift
                ;;
            --check-imds)
                CHECK_IMDS=true
                shift
                ;;
            --check-exposed-api-endpoints)
                CHECK_EXPOSED_API_ENDPOINTS=true
                shift
                ;;
            --check-helm-tiller)
                CHECK_HELM_TILLER=true
                shift
                ;;
            --check-kubelet)
                CHECK_KUBELET=true
                shift
                ;;
            --check-security-context)
                CHECK_SECURITY_CONTEXT=true
                shift
                ;;
            --collect-cr)
                COLLECT_CUSTOM_RESOURCES=true
                shift
                ;;
            --check-host-network)
                CHECK_HOST_NETWORK=true
                shift
                ;;
            --check-hostpid)
                CHECK_HOSTPID=true
                shift
                ;;
            --check-host-path-mount)
                CHECK_HOST_PATH_MOUNT=true
                shift
                ;;
            --check-psp)
                CHECK_PSP=true
                shift
                ;;
            --check-psa)
                CHECK_PSA=true
                shift
                ;;
            --check-kube-bench)
                CHECK_KUBE_BENCH=true
                shift
                ;;
            --download-manifests)
                DOWNLOAD_MANIFESTS=true
                shift
                ;;
            --kube-score)
                KUBE_SCORE_ENABLED=true
                shift
                ;;
            --check-third-party-image)
                CHECK_THIRD_PARTY_IMAGE=true
                shift
                ;;
            --all-checks)
                ALL_CHECKS=true
                shift
                ;;
            --meta)
                COLLECT_META=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --threads)
                THREADS=$2
                shift 2
                ;;
            -h|--help)
                display_help
                ;;
            *)
                log "Unknown option: $1" ERROR
                display_help
                ;;
        esac
    done
}

# ================================
# Check Dependencies Function
# ================================

check_dependencies_main() {
    log "Checking for required commands..." INFO
    local dependencies=("kubectl" "jq" "parallel")
    local missing=()

    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ "${#missing[@]}" -ne 0 ]; then
        log "The following required commands are missing: ${missing[*]}" ERROR
        exit 1
    fi

    if [[ ! "$THREADS" =~ ^[0-9]+$ ]] || [ "$THREADS" -lt 1 ]; then
        log "Invalid threads value: $THREADS. Using default of 1." WARN
        THREADS=1
    fi

    log "All required commands are available." SUCCESS
}

# ================================
# Load Modules Function
# ================================

load_modules_main() {
    log "Loading all modules..." INFO

    local module_dir="$(dirname "$0")/modules"

    if [[ ! -d "$module_dir" ]]; then
        log "Module directory not found: $module_dir" ERROR
        exit 1
    fi

    for module_file in "$module_dir"/*.sh; do
        if [[ -f "$module_file" ]]; then
            log "Loading module: $(basename "$module_file")" INFO
            source "$module_file"
        fi
    done

    # Export dynamically loaded functions for GNU parallel
    for func in $(declare -F | awk '{print $3}'); do
        export -f "$func"
    done

    log "All modules loaded successfully." SUCCESS
}

# ================================
# Execute Check Wrapper Function
# ================================

execute_check() {
    local check_name="$1"
    if declare -f "$check_name" > /dev/null; then
        "$check_name"
    else
        log "Function '$check_name' not found. Skipping..." WARN
    fi
}

# ================================
# Execute All Checks Function
# ================================

execute_all_checks() {
    local checks=()

    if [ "$ALL_CHECKS" = true ]; then
        checks=(
            "check_exposed_secrets"
            "check_env_variables"
            "check_privileged_pods"
            "check_api_access"
            "check_ingress"
            "check_egress"
            "check_rbac"
            "check_labels"
            "check_failed_pods"
            "check_resources"
            "check_imds_vulnerability"
            "check_exposed_api_endpoints"
            "check_helm_tiller"
            "check_kubelet_access"
            "check_security_context"
            "check_host_network"
            "check_hostpid_exploitability"
            "check_host_path_mount"
            "check_pod_security_policies"
            "check_pod_security_admission"
            "check_third_party_image"
            "collect_custom_resources"
            "download_manifests"
            "check_kube_bench"
            "collect_meta_artifacts"  
        )
    else
        [ "$CHECK_SECRETS" = true ] && checks+=("check_exposed_secrets")
        [ "$CHECK_ENV_VARS" = true ] && checks+=("check_env_variables")
        [ "$CHECK_PRIVILEGED" = true ] && checks+=("check_privileged_pods")
        [ "$CHECK_API_ACCESS" = true ] && checks+=("check_api_access")
        [ "$CHECK_INGRESS" = true ] && checks+=("check_ingress")
        [ "$CHECK_EGRESS" = true ] && checks+=("check_egress")
        [ "$CHECK_RBAC" = true ] && checks+=("check_rbac")
        [ "$CHECK_LABELS" = true ] && checks+=("check_labels")
        [ "$CHECK_FAILED_PODS" = true ] && checks+=("check_failed_pods")
        [ "$CHECK_RESOURCES" = true ] && checks+=("check_resources")
        [ "$CHECK_IMDS" = true ] && checks+=("check_imds_vulnerability")
        [ "$CHECK_EXPOSED_API_ENDPOINTS" = true ] && checks+=("check_exposed_api_endpoints")
        [ "$CHECK_HELM_TILLER" = true ] && checks+=("check_helm_tiller")
        [ "$CHECK_KUBELET" = true ] && checks+=("check_kubelet_access")
        [ "$CHECK_SECURITY_CONTEXT" = true ] && checks+=("check_security_context")
        [ "$CHECK_HOST_NETWORK" = true ] && checks+=("check_host_network")
        [ "$CHECK_HOSTPID" = true ] && checks+=("check_hostpid_exploitability")
        [ "$CHECK_HOST_PATH_MOUNT" = true ] && checks+=("check_host_path_mount")
        [ "$CHECK_PSP" = true ] && checks+=("check_pod_security_policies")
        [ "$CHECK_PSA" = true ] && checks+=("check_pod_security_admission")
        [ "$CHECK_THIRD_PARTY_IMAGE" = true ] && checks+=("check_third_party_image")
        [ "$COLLECT_CUSTOM_RESOURCES" = true ] && checks+=("collect_custom_resources")
        [ "$DOWNLOAD_MANIFESTS" = true ] && checks+=("download_manifests")
        [ "$CHECK_KUBE_BENCH" = true ] && checks+=("check_kube_bench")
        [ "$COLLECT_META" = true ] && checks+=("collect_meta_artifacts")
    fi

    # Validate if KUBE_SCORE_ENABLED is true
    if [ "$KUBE_SCORE_ENABLED" = true ]; then
        checks+=("run_kube_score")
    fi

    # Handle --meta separately if not using --all-checks
    if [ "$ALL_CHECKS" != true ] && [ "$COLLECT_META" = true ]; then
        checks+=("collect_meta_artifacts")
    fi

    if [ "${#checks[@]}" -eq 0 ]; then
        log "No checks specified to run." WARN
        return
    fi

    if [ "$THREADS" -gt 1 ] && command -v parallel &>/dev/null; then
        log "Running checks with $THREADS threads using GNU parallel..." INFO
        printf '%s\n' "${checks[@]}" | parallel --bar -j "$THREADS" execute_check || {
            log "Threaded execution failed. Falling back to sequential execution..." WARN
            for check in "${checks[@]}"; do
                execute_check "$check"
            done
        }
    else
        log "Running checks sequentially..." INFO
        for check in "${checks[@]}"; do
            execute_check "$check"
        done
    fi
}

# ================================
# Main Execution Function
# ================================

main() {
    # Parse arguments
    parse_arguments_main "$@"

    # Check dependencies
    check_dependencies_main

    # Load all modules
    load_modules_main

    # Export necessary functions for parallel execution
    export -f execute_check
    export -f log
    export -f show_spinner
    export THREADS
    export NAMESPACE
    export OUTPUT_DIR
    export OUTPUT_FORMAT
    export DRY_RUN
    export VERBOSE

    # Prepare output directory
    execute_check "prepare_output_directory"

    # Execute all checks
    execute_all_checks

    # Generate summary report
    execute_check "generate_summary"

    log "Audit completed. Results are saved to ${OUTPUT_DIR}." SUCCESS
}

# Invoke main with all script arguments
main "$@"
