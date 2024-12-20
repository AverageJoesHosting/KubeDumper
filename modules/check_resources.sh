#!/bin/bash

# ================================
# Check for Missing Resource Limits and Requests
# ================================

check_resources() {
    log "Checking for missing resource limits and requests..." INFO
    log "Starting check_resources." INFO

    for ns in $(get_namespaces); do
        log "Scanning resource limits in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/resources"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check resource limits in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        if kubectl get pods -n "$ns" -o json | jq -r '
            .items[] |
            select(
                (.spec.containers[]?.resources.requests == null) or
                (.spec.containers[]?.resources.limits == null)
            ) |
            "Pod \(.metadata.name) is missing resource requests or limits"
        ' > "$ns_dir/missing_resources.txt" 2>/dev/null; then
            if [[ -s "$ns_dir/missing_resources.txt" ]]; then
                log "Pods missing resource limits/requests found in namespace '$ns'. See $ns_dir/missing_resources.txt." WARN
            else
                log "All pods in namespace '$ns' have proper resource limits and requests." INFO
                rm -f "$ns_dir/missing_resources.txt"
            fi
        else
            log "Failed to retrieve pods or check resources in namespace '$ns'." ERROR
            rm -f "$ns_dir/missing_resources.txt"
        fi
    done

    log "Completed check_resources." SUCCESS
}
