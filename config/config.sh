#!/usr/bin/env bash

# ================================
# KubeDumper Configuration
# ================================

# ================================
# Output Settings
# ================================
OUTPUT_DIR="./output/k8s_audit_results"
OUTPUT_FORMAT="text"         # Options: text, json, html
NAMESPACE="all"              # Default to all namespaces

# ================================
# Execution Controls
# ================================
ALL_CHECKS=false
DRY_RUN=false                # Boolean flag
VERBOSE=false                # Boolean flag
THREADS=1                    # Default single-threaded
META_REQUESTED=false        # Track if meta was explicitly requested

# ================================
# Color Definitions
# ================================
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ================================
# Logging Configuration
# ================================
LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/kubeDumper.log"

# Ensure the logs directory exists
mkdir -p "$LOG_DIR" || { echo -e "${RED}Error: Failed to create logs directory.${NC}"; exit 1; }

# ================================
# Tool-Specific Settings
# ================================
KUBE_SCORE_ENABLED=false      # Boolean flag to enable kube-score analysis
