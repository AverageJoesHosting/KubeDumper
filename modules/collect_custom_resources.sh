#!/bin/bash

# ================================
# Collect Custom Resources (CRs)
# ================================

collect_custom_resources() {
    log "Collecting all custom resources (CRs)..." INFO
    log "Starting collect_custom_resources." INFO
    local cr_dir="$OUTPUT_DIR/custom_resources"

    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would create directory $cr_dir and collect custom resources." WARN
        return
    fi

    mkdir -p "$cr_dir" || { log "Error: Failed to create directory $cr_dir." ERROR; return; }

    # Get a list of all CustomResourceDefinitions (CRDs)
    log "Fetching all CustomResourceDefinitions (CRDs)..." INFO
    kubectl get crds -o json > "$cr_dir/crds.json" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        log "Failed to retrieve CRDs from the cluster." ERROR
        return
    fi

    if [[ -s "$cr_dir/crds.json" ]]; then
        log "CRDs successfully fetched. Parsing to identify custom resources..." INFO
        jq -r '.items[].spec.names.plural' "$cr_dir/crds.json" > "$cr_dir/cr_names.txt"
    else
        log "No CRDs found in the cluster." WARN
        return
    fi

    # Iterate through each custom resource type and collect instances
    log "Collecting instances of custom resources..." INFO
    while IFS= read -r cr_name; do
        log "Processing custom resource type: $cr_name" INFO
        local cr_type_dir="$cr_dir/$cr_name"
        mkdir -p "$cr_type_dir" || { log "Error: Failed to create directory $cr_type_dir for $cr_name." ERROR; continue; }

        kubectl get "$cr_name" -A -o yaml > "$cr_type_dir/instances.yaml" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            log "Failed to retrieve instances of custom resource: $cr_name." ERROR
            rm -rf "$cr_type_dir"
        else
            log "Custom resource instances for $cr_name collected and saved in $cr_type_dir/instances.yaml." INFO
        fi
    done < "$cr_dir/cr_names.txt"

    log "Completed collecting custom resources. Results saved in $cr_dir." SUCCESS
}
