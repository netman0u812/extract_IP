#!/bin/bash

show_help() {
    cat << EOF
Usage:
  $0 [-o <CIDR_LIST>] [-m <OCTET>] [-k <first|last>] [-d] [-t] [-r|-rv] <input_file> [<output_file>]

Options:
  -o <CIDR_LIST>    Comma-separated list of CIDRs to ignore (e.g., "/32,/31,/30")
  -m <OCTET>        Deduplicate based on octet depth:
                      1 = first octet
                      2 = first two octets
                      3 = first three octets
  -k <first|last>   Keep first or last occurrence (default: first)
  -d                Debug mode
  -t                Timestamp output filename
  -r                Summary report
  -rv               Detailed report
  -h                Show help
  -example          Show examples
EOF
}

show_examples() {
    cat << EOF
Examples:
  $0 networks.txt unique.txt
  $0 -o "/32" -m 3 -k last -rv -t networks.txt
EOF
}

IGNORE_LIST=""
MATCH_OCTET=""
KEEP_MODE="first"
DEBUG=false
TIMESTAMP=false
REPORT_MODE=""
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) IGNORE_LIST="$2"; shift 2 ;;
        -m) MATCH_OCTET="$2"; shift 2 ;;
        -k) KEEP_MODE="$2"; shift 2 ;;
        -d) DEBUG=true; shift ;;
        -t) TIMESTAMP=true; shift ;;
        -r) REPORT_MODE="summary"; shift ;;
        -rv) REPORT_MODE="detailed"; shift ;;
        -h) show_help; exit 0 ;;
        -example) show_examples; exit 0 ;;
        *) POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [ $# -lt 1 ]; then
    echo "Error: Missing input file."
    show_help
    exit 1
fi

INPUT_FILE="$1"

if $TIMESTAMP; then
    DATESTAMP=$(date +"%m-%d_%I-%M-%p")
    OUTPUT_FILE="network_list-${DATESTAMP}.txt"
    REPORT_FILE="report-${DATESTAMP}.txt"
else
    if [ $# -eq 2 ]; then
        OUTPUT_FILE="$2"
        REPORT_FILE="report.txt"
    else
        echo "Error: Missing output file (or use -t)."
        exit 1
    fi
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found."
    exit 1
fi

awk_filter='NF'
if [ -n "$IGNORE_LIST" ]; then
    IFS=',' read -ra CIDRS <<< "$IGNORE_LIST"
    for cidr in "${CIDRS[@]}"; do
        escaped_cidr=$(echo "$cidr" | sed 's/\//\\\//g')
        awk_filter="$awk_filter && \$0 !~ /${escaped_cidr}\$/"
    done
fi

filtered=$(awk "$awk_filter" "$INPUT_FILE" | awk '{$1=$1}1')

if [ -z "$MATCH_OCTET" ]; then
    # Simple dedup
    if [ "$KEEP_MODE" = "first" ]; then
        echo "$filtered" | sort -u > "$OUTPUT_FILE"
    else
        echo "$filtered" | tac | awk '!seen[$0]++' | tac > "$OUTPUT_FILE"
    fi
    echo "Deduplicated CIDR list saved to $OUTPUT_FILE"
    exit 0
fi

# Prepare report header if needed
if [ -n "$REPORT_MODE" ]; then
    echo "=== Deduplication Report ===" > "$REPORT_FILE"
    echo "Prefix depth: $MATCH_OCTET | Mode: $KEEP_MODE | Timestamp: $DATESTAMP" >> "$REPORT_FILE"
    echo "===========================================" >> "$REPORT_FILE"
fi

# Dedup by prefix using awk
prefix_cmd=""
case "$MATCH_OCTET" in
    1) prefix_cmd='{print $1}' ;;
    2) prefix_cmd='{print $1"."$2}' ;;
    3) prefix_cmd='{print $1"."$2"."$3}' ;;
    *) echo "Invalid -m value"; exit 1 ;;
esac

# Generate prefix groups
tmpfile=$(mktemp)
echo "$filtered" | awk -F'[./]' "$prefix_cmd" | sort -u | while read prefix; do
    matches=$(grep "^$prefix\." <<< "$filtered")
    count=$(echo "$matches" | wc -l | tr -d ' ')
    if [ "$KEEP_MODE" = "first" ]; then
        kept=$(echo "$matches" | head -n 1)
    else
        kept=$(echo "$matches" | tail -n 1)
    fi
    echo "$kept" >> "$OUTPUT_FILE"

    if [ -n "$REPORT_MODE" ]; then
        if [ "$REPORT_MODE" = "summary" ]; then
            echo "$kept match_hit $count" >> "$REPORT_FILE"
        else
            echo "$kept match_hit $count" >> "$REPORT_FILE"
            if [ $count -gt 1 ]; then
                dropped=$(echo "$matches" | tail -n +2 | tr '\n' ',' | sed 's/,$//')
                echo "  dropped: $dropped" >> "$REPORT_FILE"
            fi
        fi
    fi
done

# Summary
total_prefixes=$(awk -F'[./]' "$prefix_cmd" <<< "$filtered" | sort -u | wc -l | tr -d ' ')
total_networks=$(echo "$filtered" | wc -l | tr -d ' ')
total_dropped=$((total_networks - total_prefixes))

echo "Deduplicated CIDR list saved to $OUTPUT_FILE"
[ -n "$REPORT_MODE" ] && echo "Report generated: $REPORT_FILE"
echo ""
echo "Summary:"
echo "Total prefixes processed: $total_prefixes"
echo "Total networks processed: $total_networks"
echo "Total networks dropped: $total_dropped"

rm -f "$tmpfile"

