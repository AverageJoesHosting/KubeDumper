#!/bin/bash

# ================================
# Check for Helm Tiller
# ================================

check_helm_tiller() {
    log "Checking for Helm Tiller components..." INFO
    log "Starting check_helm_tiller." INFO

    for ns in $(get_namespaces); do
        log "Scanning Helm Tiller components in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/helm_tiller"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check for Helm Tiller in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        # Search for Tiller pods in the namespace
        if kubectl get pods -n "$ns" -l app=helm -o json > "$ns_dir/tiller_pods.json" 2>/dev/null; then
            if [[ -s "$ns_dir/tiller_pods.json" ]]; then
                log "Tiller pods detected in namespace '$ns'. See $ns_dir/tiller_pods.json for details." WARN

                # Parse for potential security issues (e.g., privileged Tiller pods)
                jq -r '
                    .items[] |
                    "Tiller Pod: \(.metadata.name) - Privileged: \(.spec.containers[].securityContext.privileged // false)"
                ' "$ns_dir/tiller_pods.json" > "$ns_dir/tiller_privileged.txt"

                if [[ -s "$ns_dir/tiller_privileged.txt" ]]; then
                    log "Privileged Tiller pods detected in namespace '$ns'. See $ns_dir/tiller_privileged.txt." WARN
                else
                    log "No privileged Tiller pods detected in namespace '$ns'." INFO
                    rm -f "$ns_dir/tiller_privileged.txt"
                fi
            else
                log "No Tiller pods found in namespace '$ns'." SUCCESS
                rm -f "$ns_dir/tiller_pods.json"
            fi
        else
            log "Failed to retrieve Tiller pods in namespace '$ns'." ERROR
            rm -f "$ns_dir/tiller_pods.json"
        fi

        # Search for Tiller service accounts in the namespace
        if kubectl get serviceaccounts -n "$ns" -o json | jq -r '.items[] | select(.metadata.name | contains("tiller"))' > "$ns_dir/tiller_serviceaccounts.json" 2>/dev/null; then
            if [[ -s "$ns_dir/tiller_serviceaccounts.json" ]]; then
                log "Tiller-related service accounts detected in namespace '$ns'. See $ns_dir/tiller_serviceaccounts.json." WARN
            else
                log "No Tiller-related service accounts detected in namespace '$ns'." SUCCESS
                rm -f "$ns_dir/tiller_serviceaccounts.json"
            fi
        else
            log "Failed to retrieve service accounts in namespace '$ns'." ERROR
            rm -f "$ns_dir/tiller_serviceaccounts.json"
        fi

        # Search for Tiller cluster roles and bindings (cluster-wide, but results saved per namespace for consistency)
        if kubectl get clusterroles,clusterrolebindings -o json > "$ns_dir/tiller_rbac.json" 2>/dev/null; then
            if [[ -s "$ns_dir/tiller_rbac.json" ]]; then
                jq -r '
                    .items[] |
                    select(.metadata.name | contains("tiller")) |
                    "Tiller RBAC: \(.metadata.name)"
                ' "$ns_dir/tiller_rbac.json" > "$ns_dir/tiller_rbac.txt"

                if [[ -s "$ns_dir/tiller_rbac.txt" ]]; then
                    log "Tiller RBAC configurations detected in namespace '$ns'. See $ns_dir/tiller_rbac.txt." WARN
                else
                    log "No Tiller RBAC configurations detected in namespace '$ns'." INFO
                    rm -f "$ns_dir/tiller_rbac.txt"
                fi
            else
                log "No Tiller RBAC configurations found in namespace '$ns'." SUCCESS
                rm -f "$ns_dir/tiller_rbac.json"
            fi
        else
            log "Failed to retrieve RBAC configurations for namespace '$ns'." ERROR
            rm -f "$ns_dir/tiller_rbac.json"
        fi
    done

    log "Completed check_helm_tiller." SUCCESS
}
