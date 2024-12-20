#!/bin/bash

# ================================
# Check Pod Security Policies
# ================================

check_pod_security_policies() {
    log "Checking Pod Security Policies (PSPs)..." INFO
    log "Starting check_pod_security_policies." INFO

    for ns in $(get_namespaces); do
        log "Evaluating PSPs for namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/pod_security_policies"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and evaluate PSPs for namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        # Retrieve PSPs
        if kubectl get psp -o json > "$ns_dir/psps.json" 2>/dev/null; then
            if [[ -s "$ns_dir/psps.json" ]]; then
                log "Pod Security Policies retrieved for namespace '$ns'. Analyzing configurations..." INFO

                # Evaluate risky configurations
                jq -r '
                    .items[] |
                    select(
                        .spec.privileged == true or
                        (.spec.runAsUser?.rule // "null") == "RunAsAny" or
                        (.spec.allowPrivilegeEscalation == true) or
                        (.spec.volumes | index("hostPath")) or
                        (.spec.hostNetwork == true or .spec.hostPID == true or .spec.hostIPC == true)
                    ) |
                    "PSP: \(.metadata.name) is overly permissive:\n" +
                    "- Privileged: \(.spec.privileged // "false")\n" +
                    "- RunAsUser: \(.spec.runAsUser?.rule // "null")\n" +
                    "- AllowPrivilegeEscalation: \(.spec.allowPrivilegeEscalation // "false")\n" +
                    "- Volumes: \(.spec.volumes // "none")\n" +
                    "- HostNetwork: \(.spec.hostNetwork // "false")\n" +
                    "- HostPID: \(.spec.hostPID // "false")\n" +
                    "- HostIPC: \(.spec.hostIPC // "false")\n"
                ' "$ns_dir/psps.json" > "$ns_dir/risky_psps.txt"

                if [[ -s "$ns_dir/risky_psps.txt" ]]; then
                    log "Risky PSPs found in namespace '$ns'. See $ns_dir/risky_psps.txt." WARN
                else
                    log "No risky PSPs detected in namespace '$ns'." SUCCESS
                    rm -f "$ns_dir/risky_psps.txt"
                fi

                # Collect a summary of all PSPs
                jq -r '
                    .items[] |
                    "PSP: \(.metadata.name)\n" +
                    "- Privileged: \(.spec.privileged // "false")\n" +
                    "- RunAsUser: \(.spec.runAsUser?.rule // "null")\n" +
                    "- AllowPrivilegeEscalation: \(.spec.allowPrivilegeEscalation // "false")\n" +
                    "- Volumes: \(.spec.volumes // "none")\n" +
                    "- HostNetwork: \(.spec.hostNetwork // "false")\n" +
                    "- HostPID: \(.spec.hostPID // "false")\n" +
                    "- HostIPC: \(.spec.hostIPC // "false")\n"
                ' "$ns_dir/psps.json" > "$ns_dir/psp_summary.txt"

                log "PSP summary saved to $ns_dir/psp_summary.txt." INFO
            else
                log "No PSP data retrieved for namespace '$ns'." WARN
                rm -f "$ns_dir/psps.json"
            fi
        else
            log "Failed to retrieve PSPs for namespace '$ns'." ERROR
            rm -f "$ns_dir/psps.json"
        fi
    done

    log "Completed check_pod_security_policies." SUCCESS
}
