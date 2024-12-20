#!/bin/bash

# ================================
# Generate Summary Report
# ================================

generate_summary() {
    echo -e "${CYAN}Generating summary report...${NC}"
    log "Starting generate_summary."
    local summary_file="$OUTPUT_DIR/summary_report.$OUTPUT_FORMAT"

    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY-RUN] Would generate summary report at $summary_file.${NC}"
        log "[DRY-RUN] Skipped generating summary report."
        return
    fi

    case "$OUTPUT_FORMAT" in
        json)
            jq -n \
                --arg timestamp "$(date '+%Y-%m-%d %H:%M:%S')" \
                --arg namespaces "$(get_namespaces | tr ' ' ',')" \
                --arg output_dir "$OUTPUT_DIR" \
                '{
                    summary: {
                        timestamp: $timestamp,
                        namespaces_scanned: $namespaces,
                        results_saved_to: $output_dir
                    }
                }' > "$summary_file"
            ;;
        html)
            {
                echo "<html><head><title>Summary Report - KubeDumper</title></head><body>"
                echo "<h1>Summary Report - KubeDumper</h1>"
                echo "<p><strong>Timestamp:</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>"
                echo "<p><strong>Namespaces Scanned:</strong> $(get_namespaces)</p>"
                echo "<p><strong>Results Saved To:</strong> $OUTPUT_DIR</p>"
                echo "</body></html>"
            } > "$summary_file"
            ;;
        *)
            # Default to text
            {
                echo "Summary Report - KubeDumper"
                echo "=========================="
                echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "Namespaces scanned: $(get_namespaces)"
                echo "Results saved to: $OUTPUT_DIR"
            } > "$summary_file"
            ;;
    esac

    echo -e "${GREEN}Summary report saved to $summary_file.${NC}"
    log "Summary report generated at $summary_file."
    log "Completed generate_summary."
}
