#!/bin/bash

# ================================
# Check Security Context Configurations
# ================================

check_security_context() {
    log "Checking for exploitable security contexts..." INFO
    log "Starting check_security_context." INFO

    # Meta directory for consolidated results
    local meta_dir="$OUTPUT_DIR/meta/security_context"
    mkdir -p "$meta_dir" || { log "Error: Failed to create meta directory $meta_dir." ERROR; return; }

    # Consolidate all pods data
    if kubectl get pods -A -o json > "$meta_dir/pods.json" 2>/dev/null; then
        if [[ -s "$meta_dir/pods.json" ]]; then
            log "Consolidated pod data saved to $meta_dir/pods.json." INFO
        else
            log "No consolidated pod data retrieved." WARN
            rm -f "$meta_dir/pods.json"
        fi
    else
        log "Failed to retrieve consolidated pod data." ERROR
        rm -f "$meta_dir/pods.json"
    fi

    # Namespace-specific processing
    for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        log "Analyzing security contexts for namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/security_context"
        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        if kubectl get pods -n "$ns" -o json > "$ns_dir/pods.json" 2>/dev/null; then
            if [[ -s "$ns_dir/pods.json" ]]; then
                log "Pod data for namespace '$ns' saved to $ns_dir/pods.json." INFO

                # Check for privileged containers
                jq -r '
                    .items[] |
                    .spec.containers[]? |
                    select(.securityContext.privileged == true) |
                    "Privileged container: \(.name) in pod \(.metadata.name) (namespace: \(.metadata.namespace))"
                ' "$ns_dir/pods.json" > "$ns_dir/privileged_containers.txt"

                # Check for unrestricted capabilities
                jq -r '
                    .items[] |
                    .spec.containers[]? |
                    select(.securityContext.capabilities.add? | index("ALL")) |
                    "Container with unrestricted capabilities: \(.name) in pod \(.metadata.name) (namespace: \(.metadata.namespace))"
                ' "$ns_dir/pods.json" > "$ns_dir/unrestricted_capabilities.txt"

                # Check for containers running as root
                jq -r '
                    .items[] |
                    .spec.containers[]? |
                    select(.securityContext.runAsUser == 0 or .securityContext.runAsUser == null) |
                    "Container running as root: \(.name) in pod \(.metadata.name) (namespace: \(.metadata.namespace))"
                ' "$ns_dir/pods.json" > "$ns_dir/containers_running_as_root.txt"

                # Check for hostPath volumes
                jq -r '
                    .items[] |
                    .spec.volumes[]? |
                    select(.hostPath != null) |
                    "Pod \(.metadata.name) (namespace: \(.metadata.namespace)) uses hostPath volume: \(.hostPath.path)"
                ' "$ns_dir/pods.json" > "$ns_dir/host_path_volumes.txt"

                # Log results
                for file in "$ns_dir"/*.txt; do
                    if [[ -s $file ]]; then
                        log "$(basename "$file" .txt | sed 's/_/ /g') detected for namespace '$ns'. See $file." WARN
                    else
                        log "No $(basename "$file" .txt | sed 's/_/ /g') detected for namespace '$ns'." SUCCESS
                        rm -f "$file"
                    fi
                done
            else
                log "No pod data retrieved for namespace '$ns'." WARN
                rm -f "$ns_dir/pods.json"
            fi
        else
            log "Failed to retrieve pod data for namespace '$ns'." ERROR
        fi
    done

    log "Completed check_security_context." SUCCESS
}
