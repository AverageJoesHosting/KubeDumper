#!/bin/bash

# ================================
# Enhanced Check RBAC Configurations
# ================================

check_rbac() {
    log "Checking RBAC configurations..." INFO
    log "Starting check_rbac." INFO

    # Centralized directory for consolidated RBAC data
    local meta_dir="$OUTPUT_DIR/meta/rbac"
    mkdir -p "$meta_dir" || { log "Error: Failed to create meta directory $meta_dir." ERROR; return; }

    # Consolidated collection of all RBAC data
    if kubectl get roles,rolebindings,clusterroles,clusterrolebindings -A -o json > "$meta_dir/rbac.json" 2>/dev/null; then
        if [[ -s "$meta_dir/rbac.json" ]]; then
            log "Consolidated RBAC data saved to $meta_dir/rbac.json." INFO
        else
            log "No consolidated RBAC data retrieved." WARN
            rm -f "$meta_dir/rbac.json"
        fi
    else
        log "Failed to retrieve consolidated RBAC data." ERROR
        rm -f "$meta_dir/rbac.json"
    fi

    # Namespace-specific processing
    for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
        log "Analyzing RBAC configurations for namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/rbac"
        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        if kubectl get roles,rolebindings -n "$ns" -o json > "$ns_dir/rbac.json" 2>/dev/null; then
            if [[ -s "$ns_dir/rbac.json" ]]; then
                log "RBAC data for namespace '$ns' saved to $ns_dir/rbac.json." INFO

                # Overly permissive roles
                jq -r '
                    .items[] |
                    select(.rules?[]?.resources? | index("*")) |
                    "Overly permissive role: \(.metadata.name) in namespace \(.metadata.namespace)"
                ' "$ns_dir/rbac.json" > "$ns_dir/rbac_misconfigurations.txt" 2>/dev/null

                if [[ -s "$ns_dir/rbac_misconfigurations.txt" ]]; then
                    log "RBAC misconfigurations found in namespace '$ns'. See $ns_dir/rbac_misconfigurations.txt." WARN
                else
                    rm -f "$ns_dir/rbac_misconfigurations.txt"
                fi

                # Sensitive permissions
                jq -r '
                    .items[] |
                    select(.rules?[]?.verbs? | index("create") or index("*")) |
                    "Role: \(.metadata.name) grants sensitive permissions in namespace \(.metadata.namespace)"
                ' "$ns_dir/rbac.json" > "$ns_dir/sensitive_permissions.txt" 2>/dev/null

                if [[ -s "$ns_dir/sensitive_permissions.txt" ]]; then
                    log "Roles with sensitive permissions found in namespace '$ns'. See $ns_dir/sensitive_permissions.txt." WARN
                else
                    rm -f "$ns_dir/sensitive_permissions.txt"
                fi
            else
                log "No RBAC data retrieved for namespace '$ns'." WARN
                rm -f "$ns_dir/rbac.json"
            fi
        else
            log "Failed to retrieve RBAC data for namespace '$ns'." ERROR
        fi
    done

    # Analyze cluster-wide RBAC configurations
    log "Analyzing cluster-wide RBAC configurations..." INFO
    if kubectl get clusterroles,clusterrolebindings -o json > "$meta_dir/cluster_rbac.json" 2>/dev/null; then
        if [[ -s "$meta_dir/cluster_rbac.json" ]]; then
            jq -r '
                .items[] |
                select(.metadata.name == "cluster-admin" or .roleRef.name == "cluster-admin") |
                "Cluster-admin role or binding: \(.metadata.name)\nSubjects: \(.subjects[]?.name // "No subjects found")"
            ' "$meta_dir/cluster_rbac.json" > "$meta_dir/cluster_admin_details.txt" 2>/dev/null

            if [[ -s "$meta_dir/cluster_admin_details.txt" ]]; then
                log "Cluster-admin details recorded. See $meta_dir/cluster_admin_details.txt." WARN
            else
                log "No cluster-admin details found in cluster-wide RBAC configurations." INFO
            fi
        else
            log "No cluster-wide RBAC data retrieved." WARN
            rm -f "$meta_dir/cluster_rbac.json"
        fi
    else
        log "Failed to retrieve cluster-wide RBAC data." ERROR
        rm -f "$meta_dir/cluster_rbac.json"
    fi

    log "Completed check_rbac." SUCCESS
}
