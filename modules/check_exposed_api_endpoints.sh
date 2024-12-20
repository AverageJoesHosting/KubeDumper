#!/bin/bash

# ================================
# Check for Exposed API Server Endpoints
# ================================

check_exposed_api_endpoints() {
    log "Checking for exposed API server endpoints..." INFO
    log "Starting check_exposed_api_endpoints." INFO

    for ns in $(get_namespaces); do
        log "Scanning API server endpoints in namespace '$ns'..." INFO
        local ns_dir="$OUTPUT_DIR/$ns/exposed_api_endpoints"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY-RUN] Would create directory $ns_dir and check exposed API server endpoints in namespace '$ns'." WARN
            continue
        fi

        mkdir -p "$ns_dir" || { log "Error: Failed to create directory $ns_dir." ERROR; continue; }

        # Fetch API server discovery document
        log "Fetching Kubernetes API server endpoints for namespace '$ns'..." INFO
        if kubectl get --raw / -n "$ns" > "$ns_dir/api_server_discovery.json" 2>/dev/null; then
            if [[ -s "$ns_dir/api_server_discovery.json" ]]; then
                log "API server discovery document saved to $ns_dir/api_server_discovery.json." INFO

                # Parse and record endpoints
                jq -r '
                    .paths |
                    to_entries[] |
                    "Path: \(.key) - Methods: \(.value | keys | join(", "))"
                ' "$ns_dir/api_server_discovery.json" > "$ns_dir/api_endpoints.txt"

                if [[ -s "$ns_dir/api_endpoints.txt" ]]; then
                    log "Exposed API server endpoints recorded in $ns_dir/api_endpoints.txt." INFO
                else
                    log "No API server endpoints detected in discovery document." WARN
                    rm -f "$ns_dir/api_endpoints.txt"
                fi

                # Identify potentially unauthenticated or open endpoints
                log "Analyzing for potentially unauthenticated or open API server endpoints in namespace '$ns'..." INFO
                jq -r '
                    .paths |
                    to_entries[] |
                    select(.value | keys[] as $method | .[$method].security == null) |
                    "Open API Endpoint: Path: \(.key), Methods: \(.value | keys | join(", "))"
                ' "$ns_dir/api_server_discovery.json" > "$ns_dir/open_api_endpoints.txt"

                if [[ -s "$ns_dir/open_api_endpoints.txt" ]]; then
                    log "Potentially unauthenticated or open API endpoints found in namespace '$ns'. See $ns_dir/open_api_endpoints.txt." WARN
                else
                    log "No unauthenticated or open API endpoints detected in namespace '$ns'." SUCCESS
                    rm -f "$ns_dir/open_api_endpoints.txt"
                fi
            else
                log "API server discovery document is empty for namespace '$ns'. Could not retrieve API endpoints." WARN
                rm -f "$ns_dir/api_server_discovery.json"
            fi
        else
            log "Failed to retrieve API server discovery document for namespace '$ns'." ERROR
        fi
    done

    log "Completed check_exposed_api_endpoints." SUCCESS
}
