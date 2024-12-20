#!/bin/bash

# ================================
# Collect Meta Artifacts
# ================================

collect_meta_artifacts() {
    log "Collecting meta artifacts..." INFO
    log "Starting collect_meta_artifacts." INFO
    local meta_dir="$OUTPUT_DIR/meta"
    local dashboard_dir="$meta_dir/dashboard"

    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would create meta directory at $meta_dir and collect meta artifacts." WARN
        log "[DRY-RUN] Would check for Kubernetes Dashboard and collect details." WARN
        return
    fi

    mkdir -p "$meta_dir" || { log "Error: Failed to create meta directory: $meta_dir." ERROR; return; }
    mkdir -p "$dashboard_dir" || { log "Error: Failed to create dashboard directory: $dashboard_dir." ERROR; return; }

    # Collect various cluster information
    local commands=(
        "kubectl cluster-info > \"$meta_dir/cluster_info.txt\""
        "kubectl get nodes -o wide > \"$meta_dir/nodes.txt\""
        "kubectl get namespaces > \"$meta_dir/namespaces.txt\""
        "kubectl api-resources > \"$meta_dir/api_resources.txt\""
        "kubectl version > \"$meta_dir/version.txt\""
        "kubectl config view > \"$meta_dir/config_context.txt\""
    )

    for cmd in "${commands[@]}"; do
        eval "$cmd" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            log "Failed to execute: $cmd" ERROR
        else
            log "Executed: $cmd" INFO
        fi
    done

    # Check for Kubernetes Dashboard
    log "Checking for Kubernetes Dashboard..." INFO
    if kubectl get svc -A -o json | jq -r '
        .items[] |
        select(.metadata.labels.app == "kubernetes-dashboard") |
        "\(.metadata.namespace): \(.metadata.name) - Type: \(.spec.type), External IPs: \(.status.loadBalancer.ingress // "None")"
    ' > "$dashboard_dir/dashboard_services.txt" 2>/dev/null; then
        if [[ -s "$dashboard_dir/dashboard_services.txt" ]]; then
            log "Kubernetes Dashboard detected. See $dashboard_dir/dashboard_services.txt." WARN

            # Check for exposed endpoints
            jq -r '
                .items[] |
                select(.metadata.labels.app == "kubernetes-dashboard") |
                select(.spec.type == "LoadBalancer" or .spec.type == "NodePort") |
                "Exposed Dashboard: Namespace \(.metadata.namespace), Service \(.metadata.name), Type \(.spec.type), External IPs: \(.status.loadBalancer.ingress // "None")"
            ' "$dashboard_dir/dashboard_services.txt" > "$dashboard_dir/exposed_dashboard.txt"

            if [[ -s "$dashboard_dir/exposed_dashboard.txt" ]]; then
                log "Exposed Dashboard detected. See $dashboard_dir/exposed_dashboard.txt." WARN
            else
                log "Dashboard is not exposed externally." INFO
                rm -f "$dashboard_dir/exposed_dashboard.txt"
            fi
        else
            log "No Kubernetes Dashboard services found." SUCCESS
        fi
    else
        log "Failed to retrieve Kubernetes services for Dashboard check." ERROR
    fi

    log "Meta artifacts collected in $meta_dir." SUCCESS
    log "Completed collect_meta_artifacts." SUCCESS
}
