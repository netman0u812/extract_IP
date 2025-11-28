#!/bin/bash

usage() {
    echo "Usage: $0 -p3 <input_file> [-t] [-d <delimiter>]"
    echo "  -p3 <input_file> : Specify input file for pattern 3 processing"
    echo "  -t               : Append datestamp to output files"
    echo "  -d <delimiter>   : Specify delimiter (default: auto-detect)"
    exit 1
}

INPUT_FILE=""
DELIM=""
ADD_DATESTAMP=false

while [ $# -gt 0 ]; do
    case "$1" in
        -p3)
            INPUT_FILE="$2"
            shift 2
            ;;
        -t)
            ADD_DATESTAMP=true
            shift
            ;;
        -d)
            DELIM="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$INPUT_FILE" ] || [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not specified or does not exist."
    usage
fi

# Auto-detect delimiter (POSIX-compatible)
if [ -z "$DELIM" ]; then
    if grep '\t' "$INPUT_FILE" >/dev/null; then
        DELIM=$'\t'
    else
        DELIM=","
    fi
else
    if grep '\t' "$INPUT_FILE" >/dev/null && [ "$DELIM" != $'\t' ]; then
        echo "Warning: Provided delimiter '$DELIM' may not match detected tab delimiter."
    fi
fi

COL_COUNT=$(head -n 1 "$INPUT_FILE" | awk -F"$DELIM" '{print NF}')
if [ "$COL_COUNT" -lt 7 ]; then
    echo "Error: File must have at least 7 columns, found $COL_COUNT"
    exit 1
fi

DATESTAMP=""
if $ADD_DATESTAMP; then
    DATESTAMP="_$(date +%Y%m%d)"
fi
REPORT_DIR="report_$(date +%Y%m%d)"
mkdir -p "$REPORT_DIR"

awk -F"$DELIM" 'NR>1 && NF>0 {print $1"="$3}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_1${DATESTAMP}.txt"
awk -F"$DELIM" 'NR>1 && NF>0 {print $1"="$4}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_2${DATESTAMP}.txt"
awk -F"$DELIM" 'NR>1 && NF>0 {print $1"="$5}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_3${DATESTAMP}.txt"
awk -F"$DELIM" 'NR>1 && NF>0 {gsub(/ /,"_",$6); print $1"="$6}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_4${DATESTAMP}.txt"
awk -F"$DELIM" 'NR>1 && NF>0 {print $1"=\"" $7 "\""}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_5${DATESTAMP}.txt"

echo "Reports generated in directory: $REPORT_DIR (blank lines ignored)"
