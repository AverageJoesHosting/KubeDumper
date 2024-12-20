#!/bin/bash

# ================================
# Download Kubernetes Manifests and Optionally Run kubectl score
# ================================

download_manifests() {
    log "Downloading all Kubernetes manifests..." INFO
    log "Starting download_manifests." INFO

    # Centralized directory for meta collection
    local meta_manifest_dir="$OUTPUT_DIR/meta/manifests"
    mkdir -p "$meta_manifest_dir" || { log "Error: Failed to create meta directory: $meta_manifest_dir." ERROR; return; }

    # Define resources to fetch
    local resources=("pods" "services" "deployments" "statefulsets" "daemonsets" "replicasets" "configmaps" "secrets" "ingress")
    for resource in "${resources[@]}"; do
        log "Fetching $resource manifests..." INFO

        # Fetch manifests for all namespaces
        for ns in $(get_namespaces); do
            local ns_manifest_dir="$OUTPUT_DIR/$ns/manifests"
            mkdir -p "$ns_manifest_dir" || { log "Error: Failed to create namespace directory: $ns_manifest_dir." ERROR; continue; }

            # Save namespace-specific manifests
            if kubectl get "$resource" -n "$ns" -o yaml > "$ns_manifest_dir/$resource.yaml" 2>/dev/null; then
                if [[ -s "$ns_manifest_dir/$resource.yaml" ]]; then
                    log "Saved $resource manifests for namespace '$ns'." INFO

                    # Append to centralized collection
                    cat "$ns_manifest_dir/$resource.yaml" >> "$meta_manifest_dir/$resource.yaml"
                else
                    rm -f "$ns_manifest_dir/$resource.yaml"
                    log "No $resource found in namespace '$ns'." WARN
                fi
            else
                log "Failed to fetch $resource for namespace '$ns'." ERROR
            fi
        done
    done

    log "All manifests downloaded. Namespace-specific manifests saved under $OUTPUT_DIR/<namespace>/manifests and consolidated under $meta_manifest_dir." SUCCESS

    # Optionally run kubectl score
    if [ "$ALL_CHECKS" = "true" ] || [ "$KUBE_SCORE_ENABLED" = "true" ]; then
        run_kubectl_score "$meta_manifest_dir"
    fi

    log "Completed download_manifests." SUCCESS
}

# ================================
# Run kubectl score on Collected Manifests
# ================================

run_kubectl_score() {
    local manifest_dir="$1"
    local meta_kube_score_dir="$OUTPUT_DIR/meta/kube_score"

    log "Running kubectl score analysis on collected manifests..." INFO

    # Check if kubectl score plugin is available
    if ! kubectl plugin list | grep -q "kubectl-score"; then
        log "kubectl score plugin is not installed. Cannot run manifest analysis." ERROR
        log "Please install kubectl-score to enable this feature. See: https://github.com/zegl/kube-score" INFO
        return
    fi

    mkdir -p "$meta_kube_score_dir" || { log "Error: Failed to create meta kubectl score directory: $meta_kube_score_dir." ERROR; return; }

    # Scan all manifest files in the meta directory
    find "$manifest_dir" -type f -name "*.yaml" | while read -r manifest_file; do
        local result_file="$meta_kube_score_dir/$(basename "$manifest_file" .yaml)_score.txt"
        kubectl score "$manifest_file" > "$result_file" 2>/dev/null
        if [[ $? -eq 0 && -s "$result_file" ]]; then
            log "kubectl score analysis completed for $(basename "$manifest_file"). Results saved to $result_file." SUCCESS
        else
            log "kubectl score failed or produced no results for $(basename "$manifest_file")." ERROR
            rm -f "$result_file"
        fi
    done

    # Run kubectl score on namespace-specific manifests
    for ns in $(get_namespaces); do
        local ns_kube_score_dir="$OUTPUT_DIR/$ns/kube_score"
        mkdir -p "$ns_kube_score_dir" || { log "Error: Failed to create namespace kubectl score directory: $ns_kube_score_dir." ERROR; continue; }

        find "$OUTPUT_DIR/$ns/manifests" -type f -name "*.yaml" | while read -r ns_manifest_file; do
            local ns_result_file="$ns_kube_score_dir/$(basename "$ns_manifest_file" .yaml)_score.txt"
            kubectl score "$ns_manifest_file" > "$ns_result_file" 2>/dev/null
            if [[ $? -eq 0 && -s "$ns_result_file" ]]; then
                log "kubectl score analysis completed for namespace '$ns' manifest $(basename "$ns_manifest_file"). Results saved to $ns_result_file." SUCCESS
            else
                log "kubectl score failed or produced no results for namespace '$ns' manifest $(basename "$ns_manifest_file")." ERROR
                rm -f "$ns_result_file"
            fi
        done
    done

    log "kubectl score analysis completed. Namespace-specific results saved under $OUTPUT_DIR/<namespace>/kube_score and consolidated under $meta_kube_score_dir." SUCCESS
}
