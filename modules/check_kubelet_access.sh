#!/bin/bash

# ================================
# Check for Unauthorized Kubelet Access
# ================================

check_kubelet_access() {
    log "Checking for unauthorized kubelet access..." INFO
    log "Starting check_kubelet_access." INFO

    local meta_dir="$OUTPUT_DIR/meta/kubelet_access"

    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would create directory $meta_dir and check for kubelet unauthenticated access." WARN
        return
    fi

    mkdir -p "$meta_dir" || { log "Error: Failed to create directory $meta_dir." ERROR; return; }

    # Get the IPs of all nodes
    local node_ips
    node_ips=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    if [[ $? -ne 0 || -z "$node_ips" ]]; then
        log "Failed to retrieve node IPs or no nodes found." WARN
        return
    fi

    # Check kubelet unauthenticated endpoint on each node
    for ip in $node_ips; do
        local kubelet_url="http://$ip:10255/pods"
        log "Checking kubelet unauth endpoint at $kubelet_url..." INFO

        if curl -s --max-time 5 "$kubelet_url" > "$meta_dir/$ip-kubelet.json" 2>/dev/null; then
            if [[ -s "$meta_dir/$ip-kubelet.json" ]]; then
                log "Unauthenticated kubelet access detected on $ip. Results saved to $meta_dir/$ip-kubelet.json." WARN
            else
                rm -f "$meta_dir/$ip-kubelet.json"
                log "Kubelet unauthenticated access not detected on $ip." INFO
            fi
        else
            log "Failed to connect to kubelet endpoint on $ip." WARN
            rm -f "$meta_dir/$ip-kubelet.json"
        fi
    done

    log "Completed check_kubelet_access." SUCCESS
}
