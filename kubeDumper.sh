#!/bin/bash

# Default output directory for storing audit results
OUTPUT_DIR="./k8s_audit_results"
NAMESPACE="all" # Default to all namespaces
ALL_CHECKS=false

# Function to display help menu
display_help() {
    echo "Kubernetes Security Audit Tool"
    echo
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -n <namespace>       Specify a namespace to audit (default: all namespaces)."
    echo "  -o <output_dir>      Specify an output directory for results (default: ./k8s_audit_results)."
    echo "  --check-secrets      Check for exposed secrets."
    echo "  --check-env-vars     Check for sensitive environment variables."
    echo "  --check-privileged   Check for privileged/root pods."
    echo "  --check-api-access   Check for insecure API access."
    echo "  --check-ingress      Check for misconfigured services/ingress."
    echo "  --collect-manifests  Collect all manifests for the specified namespace or cluster."
    echo "  --all-checks         Run all checks."
    echo "  --meta               Collect meta artifacts about the cluster."
    echo "  -h, --help           Display this help menu."
    exit 0
}

# Function to validate permissions
validate_permissions() {
    if ! kubectl auth can-i list namespaces &>/dev/null; then
        echo "Error: You do not have permission to list namespaces. Exiting."
        exit 1
    fi
}

# Collect namespaces
get_namespaces() {
    if [[ "$NAMESPACE" == "all" ]]; then
        kubectl get namespaces -o jsonpath="{.items[*].metadata.name}" 2>/dev/null || echo "Error retrieving namespaces."
    else
        echo "$NAMESPACE"
    fi
}

# Function to prepare output directory
prepare_output_directory() {
    if [[ -z "$OUTPUT_DIR" ]]; then
        echo "Error: Output directory is not specified."
        exit 1
    fi

    mkdir -p "$OUTPUT_DIR" || { echo "Error: Failed to create output directory: $OUTPUT_DIR"; exit 1; }
    echo "Results will be saved to: $OUTPUT_DIR"
}

# Function to collect meta artifacts
collect_meta_artifacts() {
    echo "Collecting meta artifacts..."
    meta_dir="$OUTPUT_DIR/meta"
    mkdir -p "$meta_dir" || { echo "Error: Failed to create directory: $meta_dir"; exit 1; }

    echo "  Collecting cluster information..."
    kubectl cluster-info > "$meta_dir/cluster_info.txt" 2>/dev/null || echo "Failed to retrieve cluster information."
    kubectl get nodes -o wide > "$meta_dir/nodes.txt" 2>/dev/null || echo "Failed to retrieve node information."
    kubectl get namespaces > "$meta_dir/namespaces.txt" 2>/dev/null || echo "Failed to retrieve namespaces."
    kubectl api-resources > "$meta_dir/api_resources.txt" 2>/dev/null || echo "Failed to retrieve API resources."
    kubectl version > "$meta_dir/version.txt" 2>/dev/null || echo "Failed to retrieve Kubernetes version."
    kubectl config view > "$meta_dir/config_context.txt" 2>/dev/null || echo "Failed to retrieve configuration context."

    echo "Meta artifacts saved in $meta_dir."
}

# Function to check exposed secrets
check_exposed_secrets() {
    echo "Checking for exposed secrets..."
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/exposed_secrets"
        mkdir -p "$ns_dir"

        secrets=$(kubectl get secrets -n "$ns" -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)

        for secret in $secrets; do
            secret_file="$ns_dir/$secret.txt"
            kubectl get secret "$secret" -n "$ns" -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' > "$secret_file" 2>/dev/null

            if [ -s "$secret_file" ]; then
                echo "    Decoded secret saved to $secret_file"
            else
                rm -f "$secret_file"
                echo "    No decodable data in secret: $secret (skipped)."
            fi
        done
    done
}

# Function to check for sensitive environment variables
check_env_variables() {
    echo "Checking for sensitive environment variables..."
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/env_variables"
        mkdir -p "$ns_dir"

        pods=$(kubectl get pods -n "$ns" -o jsonpath="{.items[*].metadata.name}")

        for pod in $pods; do
            pod_file="$ns_dir/$pod.txt"
            kubectl get pod "$pod" -n "$ns" -o json | jq -r '
                .spec.containers[].env[]? | 
                "\(.name): \(.value // "ValueFrom: " + (.valueFrom | tostring))"
            ' > "$pod_file" 2>/dev/null

            if [ -s "$pod_file" ]; then
                echo "    Environment variables saved to $pod_file"
            else
                rm -f "$pod_file"
                echo "    No sensitive environment variables in pod: $pod (skipped)."
            fi
        done
    done
}

# Function to check for privileged/root pods
check_privileged_pods() {
    echo "Checking for privileged/root pods..."
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns/privileged_pods"
        mkdir -p "$ns_dir"

        pods=$(kubectl get pods -n "$ns" -o json)

        echo "$pods" | jq -r '
            .items[] | 
            select(.spec.containers[].securityContext.privileged == true or .spec.containers[].securityContext.runAsUser == 0) | 
            "\(.metadata.name): Privileged=\(.spec.containers[].securityContext.privileged), RunAsUser=\(.spec.containers[].securityContext.runAsUser)"
        ' > "$ns_dir/privileged_pods.txt"

        if [ -s "$ns_dir/privileged_pods.txt" ]; then
            echo "    Privileged/root pods found in namespace $ns. Results saved to $ns_dir/privileged_pods.txt"
        else
            echo "    No privileged/root pods found in namespace $ns."
            rm -f "$ns_dir/privileged_pods.txt"
        fi
    done
}

# Function to check for insecure API access
check_insecure_api_access() {
    echo "Checking for insecure API access..."
    local api_dir="$OUTPUT_DIR/clusterwide"
    mkdir -p "$api_dir"

    kubectl auth can-i '*' '*' --as=system:anonymous > "$api_dir/insecure_api_access.txt" 2>&1

    if grep -q "yes" "$api_dir/insecure_api_access.txt"; then
        echo "Anonymous access is allowed to the API server. Results saved to $api_dir/insecure_api_access.txt"
    else
        echo "Anonymous access is not allowed."
        rm -f "$api_dir/insecure_api_access.txt"
    fi
}

# Function to check for misconfigured services/ingress
check_misconfigured_services_ingress() {
    echo "Checking for misconfigured services and ingress..."
    for ns in $(get_namespaces); do
        echo "  Namespace: $ns"
        ns_dir="$OUTPUT_DIR/$ns"
        mkdir -p "$ns_dir"

        # Check NodePort services
        kubectl get services -n "$ns" -o json | jq -r '
            .items[] | 
            select(.spec.type == "NodePort") | 
            "\(.metadata.name): \(.spec.ports[].nodePort)"
        ' > "$ns_dir/nodeport_services.txt"

        # Check insecure ingress configurations
        kubectl get ingress -n "$ns" -o json | jq -r '
            .items[] | 
            select(.spec.tls == null) | 
            "\(.metadata.name) does not use HTTPS"
        ' > "$ns_dir/insecure_ingress.txt"
    done
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n) NAMESPACE="$2"; shift ;;
        -o) OUTPUT_DIR="$2"; shift ;;
        --check-secrets) check_exposed_secrets ;;
        --check-env-vars) check_env_variables ;;
        --check-privileged) check_privileged_pods ;;
        --check-api-access) check_insecure_api_access ;;
        --check-ingress) check_misconfigured_services_ingress ;;
        --collect-manifests) collect_meta_artifacts ;;
        --meta) collect_meta_artifacts ;;
        --all-checks) ALL_CHECKS=true ;;
        -h|--help) display_help ;;
        *) echo "Unknown option: $1"; display_help ;;
    esac
    shift
done

# Prepare the output directory
prepare_output_directory

# Run all checks if selected
if $ALL_CHECKS; then
    collect_meta_artifacts
    check_exposed_secrets
    check_env_variables
    check_privileged_pods
    check_insecure_api_access
    check_misconfigured_services_ingress
fi

echo "Audit completed. Results are saved to $OUTPUT_DIR."
