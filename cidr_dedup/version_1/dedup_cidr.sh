#!/bin/bash

# Usage:
#   dedup_cidr.sh [-o <CIDR_LIST>] <input_file> <output_file>
# Example:
#   dedup_cidr.sh -o "/32,/31,/30" networks.txt unique_networks.txt

IGNORE_LIST=""
POSITIONAL_ARGS=()

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o)
            IGNORE_LIST="$2"
            shift 2
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional arguments
set -- "${POSITIONAL_ARGS[@]}"

# Validate arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 [-o <CIDR_LIST>] <input_file> <output_file>"
    echo "CIDR_LIST example: /32,/31,/30"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found."
    exit 1
fi

# Build awk filter dynamically
awk_filter='NF'
if [ -n "$IGNORE_LIST" ]; then
    IFS=',' read -ra CIDRS <<< "$IGNORE_LIST"
    for cidr in "${CIDRS[@]}"; do
        escaped_cidr=$(echo "$cidr" | sed 's/\//\\\//g')  # Escape slash
        awk_filter="$awk_filter && \$0 !~ /${escaped_cidr}\$/"
    done
fi

# Process file: strip spaces, filter, sort unique
awk "$awk_filter" "$INPUT_FILE" | awk '{$1=$1}1' | sort -u > "$OUTPUT_FILE"

echo "Deduplicated CIDR list saved to $OUTPUT_FILE"
if [ -n "$IGNORE_LIST" ]; then
    echo "Ignored networks with CIDRs: $IGNORE_LIST"
fi
