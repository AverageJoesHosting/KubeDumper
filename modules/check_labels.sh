#!/bin/bash

# ================================
# Check for Missing 'app' Labels
# ================================

check_labels() {
    log "Checking for missing 'app' labels..." INFO
    log "Starting check_labels." INFO

    for ns in $(get_namespaces); do
        log "Scanning labels in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/labels"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check for missing 'app' labels in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        if kubectl get pods -n "$ns" -o json | jq -r '
            .items[] |
            select(.metadata.labels.app == null) |
            "Pod \(.metadata.name) is missing app label"
        ' > "$ns_dir/missing_labels.txt" 2>/dev/null; then
            if [[ -s "$ns_dir/missing_labels.txt" ]]; then
                log "Pods missing 'app' label found in namespace '$ns'. See $ns_dir/missing_labels.txt." WARN
            else
                log "All pods in namespace '$ns' have 'app' labels or no pods are present." INFO
                rm -f "$ns_dir/missing_labels.txt"
            fi
        else
            log "Failed to retrieve pods or check labels in namespace '$ns'." ERROR
            rm -f "$ns_dir/missing_labels.txt"
        fi
    done

    log "Completed check_labels." SUCCESS
}
