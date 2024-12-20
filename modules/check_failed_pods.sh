#!/bin/bash

# ================================
# Check for Failed Pods
# ================================

check_failed_pods() {
    log "Checking for failed pods..." INFO
    log "Starting check_failed_pods." INFO

    for ns in $(get_namespaces); do
        log "Scanning failed pods in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/failed_pods"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check for failed pods in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        if kubectl get pods -n "$ns" --field-selector=status.phase=Failed -o json > "$ns_dir/failed_pods.json" 2>/dev/null; then
            if [[ -s "$ns_dir/failed_pods.json" ]]; then
                log "Failed pods found in namespace '$ns'. Details saved to $ns_dir/failed_pods.json." WARN
            else
                log "No failed pods in namespace '$ns'. Cleaning up empty results file." INFO
                rm -f "$ns_dir/failed_pods.json"
            fi
        else
            log "Failed to retrieve pods for namespace '$ns'." ERROR
            rm -f "$ns_dir/failed_pods.json"
        fi
    done

    log "Completed check_failed_pods." SUCCESS
}
