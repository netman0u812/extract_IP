#!/bin/bash

show_help() {
    cat << EOF
Usage:
  $0 [-o <CIDR_LIST>] [-m <OCTET>] [-k <first|last>] [-d] <input_file> <output_file>

Options:
  -o <CIDR_LIST>    Comma-separated list of CIDRs to ignore (e.g., "/32,/31,/30")
  -m <OCTET>        Deduplicate based on octet depth:
                      1 = first octet (e.g., 10.x.x.x)
                      2 = first two octets (e.g., 10.218.x.x)
                      3 = first three octets (e.g., 10.218.1.x)
  -k <first|last>   Keep first or last occurrence when deduplicating (default: first)
  -d                Enable debug mode (prints all operations)
  -h                Show this help message
  -example          Show examples and explanations

EOF
}

show_examples() {
    cat << EOF
Examples:

1. Remove duplicates based on full IP:
   $0 networks.txt unique_networks.txt

2. Ignore /32 CIDRs:
   $0 -o "/32" networks.txt unique_networks.txt

3. Deduplicate by first 3 octets, keep first occurrence:
   $0 -m 3 networks.txt unique_networks.txt
   Explanation: If input has 10.218.1.1/30 and 10.218.1.4/30, only the first is kept.

4. Deduplicate by first 3 octets, keep last occurrence:
   $0 -m 3 -k last networks.txt unique_networks.txt
   Explanation: If input has 10.218.1.1/30 and 10.218.1.4/30, only the last is kept.

5. Ignore multiple CIDRs and deduplicate by octet:
   $0 -o "/32,/31" -m 2 networks.txt unique_networks.txt
   Explanation: Removes /32 and /31 entries, then deduplicates by first two octets.

EOF
}

IGNORE_LIST=""
MATCH_OCTET=""
KEEP_MODE="first"
DEBUG=false
POSITIONAL_ARGS=()

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) IGNORE_LIST="$2"; shift 2 ;;
        -m) MATCH_OCTET="$2"; shift 2 ;;
        -k) KEEP_MODE="$2"; shift 2 ;;
        -d) DEBUG=true; shift ;;
        -h) show_help; exit 0 ;;
        -example) show_examples; exit 0 ;;
        *) POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [ $# -ne 2 ]; then
    echo "Error: Missing input or output file."
    show_help
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found."
    exit 1
fi

# Debug info
if $DEBUG; then
    echo "[DEBUG] Input file: $INPUT_FILE"
    echo "[DEBUG] Output file: $OUTPUT_FILE"
    echo "[DEBUG] Ignore CIDRs: $IGNORE_LIST"
    echo "[DEBUG] Match octet: $MATCH_OCTET"
    echo "[DEBUG] Keep mode: $KEEP_MODE"
fi

# Build awk filter for CIDR ignore
awk_filter='NF'
if [ -n "$IGNORE_LIST" ]; then
    IFS=',' read -ra CIDRS <<< "$IGNORE_LIST"
    for cidr in "${CIDRS[@]}"; do
        escaped_cidr=$(echo "$cidr" | sed 's/\//\\\//g')
        awk_filter="$awk_filter && \$0 !~ /${escaped_cidr}\$/"
    done
fi

if $DEBUG; then
    echo "[DEBUG] AWK filter: $awk_filter"
fi

filtered=$(awk "$awk_filter" "$INPUT_FILE" | awk '{$1=$1}1')

if $DEBUG; then
    echo "[DEBUG] Filtered list:"
    echo "$filtered"
fi

# Deduplication logic
if [ -n "$MATCH_OCTET" ]; then
    case "$MATCH_OCTET" in
        1) prefix_cmd='{print $1}' ;;
        2) prefix_cmd='{print $1"."$2}' ;;
        3) prefix_cmd='{print $1"."$2"."$3}' ;;
        *) echo "Invalid value for -m. Use 1, 2, or 3."; exit 1 ;;
    esac

    if $DEBUG; then
        echo "[DEBUG] Deduplicating by first $MATCH_OCTET octet(s), keep $KEEP_MODE"
    fi

    if [ "$KEEP_MODE" == "first" ]; then
        echo "$filtered" | awk -F'[./]' "$prefix_cmd" | sort -u | while read prefix; do
            match=$(grep "^$prefix\." <<< "$filtered" | head -n 1)
            if $DEBUG; then echo "[DEBUG] Prefix: $prefix -> Keeping: $match"; fi
            echo "$match"
        done > "$OUTPUT_FILE"
    elif [ "$KEEP_MODE" == "last" ]; then
        echo "$filtered" | awk -F'[./]' "$prefix_cmd" | sort -u | while read prefix; do
            match=$(grep "^$prefix\." <<< "$filtered" | tail -n 1)
            if $DEBUG; then echo "[DEBUG] Prefix: $prefix -> Keeping: $match"; fi
            echo "$match"
        done > "$OUTPUT_FILE"
    else
        echo "Invalid value for -k. Use 'first' or 'last'."
        exit 1
    fi
else
    if [ "$KEEP_MODE" == "first" ]; then
        if $DEBUG; then echo "[DEBUG] Deduplicating full IP, keep first"; fi
        echo "$filtered" | sort -u > "$OUTPUT_FILE"
    elif [ "$KEEP_MODE" == "last" ]; then
        if $DEBUG; then echo "[DEBUG] Deduplicating full IP, keep last"; fi
        echo "$filtered" | tac | awk '!seen[$0]++' | tac > "$OUTPUT_FILE"
    fi
fi

echo "Deduplicated CIDR list saved to $OUTPUT_FILE"
if [ -n "$IGNORE_LIST" ]; then echo "Ignored CIDRs: $IGNORE_LIST"; fi
if [ -n "$MATCH_OCTET" ]; then echo "Deduplicated by first $MATCH_OCTET octet(s), keeping $KEEP_MODE occurrence"; fi
