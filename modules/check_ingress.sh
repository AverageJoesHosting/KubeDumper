#!/bin/bash

# ================================
# Check Ingress Configurations
# ================================

check_ingress() {
    log "Checking ingress configurations..." INFO
    log "Starting check_ingress." INFO

    for ns in $(get_namespaces); do
        log "Scanning ingress configurations in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/ingress"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check ingress configurations in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        if kubectl get ingress -n "$ns" -o json | jq -r '
            .items[] | select(.spec.tls == null) | "\(.metadata.name) missing HTTPS configuration"
        ' > "$ns_dir/insecure_ingress.txt" 2>/dev/null; then
            if [[ -s "$ns_dir/insecure_ingress.txt" ]]; then
                log "Insecure ingress(es) found in namespace '$ns'. See $ns_dir/insecure_ingress.txt." WARN
            else
                log "All ingress in namespace '$ns' have TLS configured or no ingress is present." INFO
                rm -f "$ns_dir/insecure_ingress.txt"
            fi
        else
            log "Failed to retrieve ingress configurations for namespace '$ns'." ERROR
            rm -f "$ns_dir/insecure_ingress.txt"
        fi
    done

    log "Completed check_ingress." SUCCESS
}
