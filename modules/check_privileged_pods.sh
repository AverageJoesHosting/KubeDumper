#!/bin/bash

# ================================
# Check for Privileged/Root Pods
# ================================

check_privileged_pods() {
    log "Checking for privileged/root pods..." INFO
    log "Starting check_privileged_pods." INFO

    for ns in $(get_namespaces); do
        log "Scanning privileged pods in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/privileged_pods"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check privileged pods in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        pods=$(kubectl get pods -n "$ns" -o json 2>/dev/null)
        if [[ $? -ne 0 || -z "$pods" ]]; then
            log "No pods found or failed to retrieve pods in namespace '$ns'." WARN
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
            log "Privileged/root pods found in namespace '$ns'. Results saved to $ns_dir/privileged_pods.txt." WARN
        else
            log "No privileged/root pods found in namespace '$ns'." INFO
            rm -f "$ns_dir/privileged_pods.txt"
        fi
    done

    log "Completed check_privileged_pods." SUCCESS
}
