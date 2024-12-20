#!/bin/bash

# ================================
# Check for Pods Using hostNetwork
# ================================

check_host_network() {
    log "Checking for pods using hostNetwork..." INFO
    log "Starting check_host_network." INFO

    for ns in $(get_namespaces); do
        log "Scanning for hostNetwork pods in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/host_network"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check for pods using hostNetwork in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        # Find pods with hostNetwork set to true
        if kubectl get pods -n "$ns" -o json | jq -r '
            .items[] |
            select(.spec.hostNetwork == true) |
            {
                pod: .metadata.name,
                namespace: .metadata.namespace,
                containers: [.spec.containers[].name],
                privileged: (.spec.containers[]?.securityContext?.privileged // "false"),
                runAsUser: (.spec.containers[]?.securityContext?.runAsUser // "not defined"),
                hostPorts: [.spec.containers[]?.ports[]?.hostPort],
                serviceAccount: (.spec.serviceAccountName // "default")
            }
        ' > "$ns_dir/host_network_pods.json" 2>/dev/null; then
            if [[ -s "$ns_dir/host_network_pods.json" ]]; then
                log "Pods using hostNetwork found in namespace '$ns'. Details in $ns_dir/host_network_pods.json." WARN

                # Further analysis for high-risk pods
                jq -r '
                    .[] |
                    select(
                        .privileged == "true" or
                        .runAsUser == 0 or
                        (.hostPorts | length > 0)
                    ) |
                    "High-risk pod detected: Pod \(.pod) in namespace \(.namespace). Privileged: \(.privileged), runAsUser: \(.runAsUser), hostPorts: \(.hostPorts // "None"), serviceAccount: \(.serviceAccount)"
                ' "$ns_dir/host_network_pods.json" > "$ns_dir/high_risk_pods.txt"

                if [[ -s "$ns_dir/high_risk_pods.txt" ]]; then
                    log "High-risk pods detected in namespace '$ns'. See $ns_dir/high_risk_pods.txt." WARN
                else
                    log "No high-risk pods detected in namespace '$ns'." SUCCESS
                    rm -f "$ns_dir/high_risk_pods.txt"
                fi
            else
                log "No pods using hostNetwork detected in namespace '$ns'." INFO
                rm -f "$ns_dir/host_network_pods.json"
            fi
        else
            log "Failed to retrieve pods using hostNetwork in namespace '$ns'." ERROR
            rm -f "$ns_dir/host_network_pods.json"
        fi
    done

    log "Completed check_host_network." SUCCESS
}
