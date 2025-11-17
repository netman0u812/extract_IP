#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 -p3 <input_file> [-t] [-d <delimiter>]"
    echo "  -p3 <input_file> : Specify input file for pattern 3 processing"
    echo "  -t               : Append datestamp to output files"
    echo "  -d <delimiter>   : Specify delimiter (default: auto-detect)"
    exit 1
}

# Initialize variables
INPUT_FILE=""
DELIM=""
ADD_DATESTAMP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
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

# Validate input file
if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not specified or does not exist."
    usage
fi

# Auto-detect delimiter if not provided
AUTO_DELIM=$(head -n 1 "$INPUT_FILE" | grep -P '	' >/dev/null && echo $'	' || echo ',')
if [[ -z "$DELIM" ]]; then
    DELIM="$AUTO_DELIM"
else
    # Warn if mismatch detected
    if [[ "$DELIM" != "$AUTO_DELIM" ]]; then
        echo "Warning: Provided delimiter '$DELIM' does not match detected delimiter '$AUTO_DELIM'."
    fi
fi

# Check column count
COL_COUNT=$(head -n 1 "$INPUT_FILE" | awk -F"$DELIM" '{print NF}')
if (( COL_COUNT < 7 )); then
    echo "Error: File must have at least 7 columns, found $COL_COUNT"
    exit 1
fi

# Prepare datestamp and output directory
DATESTAMP=""
if $ADD_DATESTAMP; then
    DATESTAMP="_$(date +%Y%m%d)"
fi
REPORT_DIR="report_$(date +%Y%m%d)"
mkdir -p "$REPORT_DIR"

# Generate reports
awk -F"$DELIM" 'NR>1 {print $1"="\$3}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_1${DATESTAMP}.txt"
awk -F"$DELIM" 'NR>1 {print $1"="\$4}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_2${DATESTAMP}.txt"
awk -F"$DELIM" 'NR>1 {print $1"="\$5}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_3${DATESTAMP}.txt"
awk -F"$DELIM" 'NR>1 {gsub(/ /,"_",\$6); print $1"="\$6}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_4${DATESTAMP}.txt"
awk -F"$DELIM" 'NR>1 {print $1"=""\$7"""}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_5${DATESTAMP}.txt"

echo "Reports generated in directory: $REPORT_DIR"
