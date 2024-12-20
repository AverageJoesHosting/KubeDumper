#!/bin/bash

# ================================
# Check Egress Configurations
# ================================

check_egress() {
    log "Checking egress configurations..." INFO
    log "Starting check_egress." INFO

    for ns in $(get_namespaces); do
        log "Scanning egress configurations in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/egress"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check egress configurations in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        # Fetch network policies and identify those with unrestricted egress
        if kubectl get networkpolicies -n "$ns" -o json | jq -r '
            .items[] |
            select(
                .spec.egress == null or
                ([.spec.egress[]?.to[]?.ipBlock.cidr] | all(. == null))
            ) |
            "\(.metadata.name) allows unrestricted egress"
        ' > "$ns_dir/unrestricted_egress.txt" 2>/dev/null; then
            if [[ -s "$ns_dir/unrestricted_egress.txt" ]]; then
                log "Unrestricted egress policies found in namespace '$ns'. See $ns_dir/unrestricted_egress.txt." WARN
            else
                log "No unrestricted egress policies found in namespace '$ns'." INFO
                rm -f "$ns_dir/unrestricted_egress.txt"
            fi
        else
            log "Failed to retrieve egress configurations for namespace '$ns'." ERROR
            rm -f "$ns_dir/unrestricted_egress.txt"
        fi
    done

    log "Completed check_egress." SUCCESS
}
