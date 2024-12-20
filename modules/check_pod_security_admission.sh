#!/bin/bash

# ================================
# Check Pod Security Admission (PSA)
# ================================

check_pod_security_admission() {
    log "Checking Pod Security Admission (PSA) configurations..." INFO
    log "Starting check_pod_security_admission." INFO

    for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        log "Analyzing PSA labels for namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/pod_security_admission"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and evaluate PSA configurations for namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        # Retrieve namespace PSA labels
        if kubectl get namespace "$ns" -o json > "$ns_dir/namespace.json" 2>/dev/null; then
            if [[ -s "$ns_dir/namespace.json" ]]; then
                jq -r '
                    {
                        namespace: .metadata.name,
                        enforce: (.metadata.labels["pod-security.kubernetes.io/enforce"] // "none"),
                        audit: (.metadata.labels["pod-security.kubernetes.io/audit"] // "none"),
                        warn: (.metadata.labels["pod-security.kubernetes.io/warn"] // "none")
                    } |
                    "Namespace: \(.namespace)\n  Enforce: \(.enforce)\n  Audit: \(.audit)\n  Warn: \(.warn)\n"
                ' "$ns_dir/namespace.json" > "$ns_dir/psa_labels.txt"

                if [[ -s "$ns_dir/psa_labels.txt" ]]; then
                    log "PSA configurations recorded for namespace '$ns'. See $ns_dir/psa_labels.txt." INFO
                else
                    log "No PSA labels detected for namespace '$ns'." WARN
                    rm -f "$ns_dir/psa_labels.txt"
                fi
            else
                log "No data retrieved for namespace '$ns'." WARN
                rm -f "$ns_dir/namespace.json"
            fi
        else
            log "Failed to retrieve PSA data for namespace '$ns'." ERROR
            rm -f "$ns_dir/namespace.json"
        fi
    done

    log "Completed check_pod_security_admission." SUCCESS
}
