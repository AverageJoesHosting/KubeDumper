#!/bin/bash

# ================================
# Check for Exposed Secrets
# ================================

check_exposed_secrets() {
    log "Checking for exposed secrets..." INFO
    log "Starting check_exposed_secrets." INFO

    for ns in $(get_namespaces); do
        log "Scanning secrets in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/exposed_secrets"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check secrets in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        secrets=$(kubectl get secrets -n "$ns" -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)
        if [[ $? -ne 0 || -z "$secrets" ]]; then
            log "No secrets found or failed to retrieve secrets in namespace '$ns'." WARN
            continue
        fi

        for secret in $secrets; do
            local secret_file="$ns_dir/$secret.txt"

            if kubectl get secret "$secret" -n "$ns" -o json | jq -r '.data | to_entries[] | "\(.key): \(.value | @base64d)"' > "$secret_file" 2>/dev/null; then
                if [[ -s "$secret_file" ]]; then
                    log "Secret '$secret' in namespace '$ns' has exposed data: saved to $secret_file." WARN
                else
                    rm -f "$secret_file"
                    log "Secret '$secret' in namespace '$ns' has no decodable data." INFO
                fi
            else
                log "Failed to process secret '$secret' in namespace '$ns'." ERROR
                rm -f "$secret_file"
            fi
        done
    done

    log "Completed check_exposed_secrets." SUCCESS
}
