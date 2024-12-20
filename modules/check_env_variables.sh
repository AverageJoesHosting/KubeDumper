#!/bin/bash

# ================================
# Check and Save Environment Variables
# ================================

check_env_variables() {
    log "Checking and saving environment variables..."
    log "Starting check_env_variables." INFO

    for ns in $(get_namespaces); do
        log "Scanning environment variables in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/env_variables"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check environment variables in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        pods=$(kubectl get pods -n "$ns" -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)
        if [[ $? -ne 0 || -z "$pods" ]]; then
            log "No pods found or failed to retrieve pods in namespace '$ns'." WARN
            continue
        fi

        for pod in $pods; do
            local pod_file="$ns_dir/$pod.txt"
            local sensitive_found=false

            if kubectl get pod "$pod" -n "$ns" -o json | jq -r '
                .spec.containers[].env[]? | "\(.name): \(.value // ("ValueFrom: " + (.valueFrom | tostring)))"
            ' > "$pod_file" 2>/dev/null; then
                if [[ -s "$pod_file" ]]; then
                    log "Environment variables for pod '$pod' saved in $pod_file." INFO

                    # Check for sensitive keywords
                    if grep -E "(PASSWORD|SECRET|TOKEN|KEY)" "$pod_file" > /dev/null 2>&1; then
                        sensitive_found=true
                    fi
                fi

                if $sensitive_found; then
                    log "Potential sensitive variables found for pod '$pod'. Review $pod_file." WARN
                else
                    log "No obvious sensitive variables detected for pod '$pod'. Saved for further review." SUCCESS
                fi
            else
                log "Error: Failed to retrieve environment variables for pod '$pod' in namespace '$ns'." ERROR
                rm -f "$pod_file"
            fi
        done
    done

    log "Completed check_env_variables." SUCCESS
}
