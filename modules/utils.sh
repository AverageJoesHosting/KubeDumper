#!/usr/bin/env bash

# ================================
# Utility Functions for KubeDumper
# ================================

# ================================
# Enhanced Logging Function
# ================================
log() {
    local message="$1"
    local level="${2:-INFO}" # Default level to INFO if not provided
    local color="${CYAN}"   # Default color for INFO
    local timestamp

    # Get the current timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    # Assign colors based on log level
    case "$level" in
        INFO) color="${CYAN}" ;;
        SUCCESS) color="${GREEN}" ;;
        WARN) color="${YELLOW}" ;;
        ERROR) color="${RED}" ;;
        *) color="${NC}" ;;
    esac

    # Write to the log file if not in dry-run mode and log file is configured
    if [[ "$DRY_RUN" != "true" && -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi

    # Print to terminal for verbose mode or on error
    if [[ "$VERBOSE" = "true" || "$level" = "ERROR" ]]; then
        echo -e "${color}[$timestamp] [$level] $message${NC}"
    fi
}
# ================================
# Spinner Function
# ================================

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinner='|/-\'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %s" "${spinner:i:1}" "Processing..." >&2
        i=$(( (i+1) % 4 ))
        sleep "$delay"
    done
    printf "\r%s\n" "Done!" >&2
}

# ================================
# Execute Check Function
# ================================

execute_check() {
    local check_name="$1"

    if [[ "$DRY_RUN" = "true" ]]; then
        log "[DRY-RUN] Would execute: $check_name" "INFO"
        return 0
    fi

    # Check if the function exists before attempting to call it
    if declare -f "$check_name" > /dev/null; then
        "$check_name"
    else
        log "Check function '$check_name' not found." "ERROR"
    fi
}

# ================================
# Prepare Output Directory
# ================================

prepare_output_directory() {
    if [[ "$DRY_RUN" = "true" ]]; then
        log "[DRY-RUN] Would create output directory at $OUTPUT_DIR" "WARN"
    else
        mkdir -p "$OUTPUT_DIR" || { log "Failed to create output directory: $OUTPUT_DIR" "ERROR"; exit 1; }
        log "Output directory prepared at $OUTPUT_DIR." "SUCCESS"
    fi
}

# ================================
# Get Namespaces to Scan
# ================================

get_namespaces() {
    if [[ "$NAMESPACE" == "all" ]]; then
        local namespaces
        namespaces=$(kubectl get namespaces -o jsonpath="{.items[*].metadata.name}" 2>/dev/null)
        if [[ $? -ne 0 || -z "$namespaces" ]]; then
            log "Failed to retrieve namespaces." "ERROR"
            exit 1
        fi
        echo "$namespaces"
    else
        echo "$NAMESPACE" | tr ',' ' '
    fi
}
