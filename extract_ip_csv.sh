#!/bin/bash

###############################################################################
# Script Name: extract_ip_csv.sh
# Version: v3
# Description:
#   Multi-pattern IP report generator supporting -p1, -p2, and -p3.
#   Creates separate output directories for each pattern.
#   Compatible with macOS and Linux.
#
# Features:
#   - Auto-detects input delimiter (tab, comma, semicolon)
#   - Ignores blank lines
#   - Adds timestamp to output files if requested
#   - Detailed help and usage examples
#   - Version flag (-v)
#   - Debug mode (-d) pipes events to stdout
###############################################################################

VERSION="v3"

show_help() {
cat <<EOF
Usage:
  ./extract_ip_csv.sh -p1|-p2|-p3 [options] input.csv [output.txt]

Patterns:
  -p1 : IP/CIDR from Column2 + Column3 + Location
  -p2 : IP/CIDR + City/State + Type + Description (only if Column2 has valid IPv4)
  -p3 : Generate 5 reports mapping Subnet to Realm, BU, Type, Location, Description

Options:
  -dl <delimiter>   Input delimiter (auto-detect if not set)
  -ds | -dt | -dc   Output delimiter: space | tab | comma (for p1/p2)
  --use-display     Use Display Name for location in Pattern 1
  -d                Debug mode (prints events to stdout)
  -t                Append timestamp to output file(s)
  -examples         Show CLI usage examples
  -v                Show script version
  -h                Show help

Run './extract_ip_csv.sh -examples' for detailed examples.
EOF
exit 0
}

show_examples() {
cat <<EOF
Examples:
  # Pattern 1 basic usage
  ./extract_ip_csv.sh -p1 input.csv

  # Pattern 1 with display name and tab delimiter
  ./extract_ip_csv.sh -p1 input.csv --use-display -dt

  # Pattern 2 basic usage
  ./extract_ip_csv.sh -p2 input.csv

  # Pattern 2 with comma output delimiter
  ./extract_ip_csv.sh -p2 input.csv -dc

  # Pattern 3 basic usage
  ./extract_ip_csv.sh -p3 input.csv

  # Pattern 3 with timestamp
  ./extract_ip_csv.sh -p3 input.csv -t

  # Show version
  ./extract_ip_csv.sh -v

  # Debug mode example
  ./extract_ip_csv.sh -p3 input.csv -d
EOF
exit 0
}

PATTERN=""
DELIM=""
OUT_DELIM=" "
DEBUG=false
TIMESTAMP=false
USE_DISPLAY=false
INPUT_FILE=""
OUTPUT_FILE=""

# Parse arguments
while [ $# -gt 0 ]; do
case "$1" in
    -p1) PATTERN="p1"; shift ;;
    -p2) PATTERN="p2"; shift ;;
    -p3) PATTERN="p3"; shift ;;
    -dl) DELIM="$2"; shift 2 ;;
    -ds) OUT_DELIM=" "; shift ;;
    -dt) OUT_DELIM=$'	'; shift ;;
    -dc) OUT_DELIM=","; shift ;;
    --use-display) USE_DISPLAY=true; shift ;;
    -d) DEBUG=true; shift ;;
    -t) TIMESTAMP=true; shift ;;
    -h|--help) show_help ;;
    -examples) show_examples ;;
    -v) echo "extract_ip_csv.sh version $VERSION"; exit 0 ;;
    *)
        if [ -z "$INPUT_FILE" ]; then INPUT_FILE="$1"
        elif [ -z "$OUTPUT_FILE" ]; then OUTPUT_FILE="$1"
        fi
        shift ;;
esac
done

# Validate
if [ -z "$PATTERN" ] || [ -z "$INPUT_FILE" ]; then
    echo "Error: Missing required arguments."; show_help
fi
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found."; exit 1
fi
if [ -z "$OUTPUT_FILE" ]; then OUTPUT_FILE="IP_Prefix_report.txt"; fi
if $TIMESTAMP; then OUTPUT_FILE="${OUTPUT_FILE%.txt}_$(date +'%d-%m_%H-%M').txt"; fi

# Auto-detect delimiter
if [ -z "$DELIM" ]; then
    first_line=$(head -n 1 "$INPUT_FILE")
    if [[ "$first_line" == *$'	'* ]]; then DELIM=$'	'
    elif [[ "$first_line" == *";"* ]]; then DELIM=";"
    else DELIM="," 
    fi
fi

DATESTAMP=""
if $TIMESTAMP; then DATESTAMP="_$(date +%Y%m%d)"; fi
REPORT_DIR="report_${PATTERN}_$(date +%Y%m%d)"
mkdir -p "$REPORT_DIR"

if $DEBUG; then
    echo "[DEBUG] Version: $VERSION"
    echo "[DEBUG] Pattern: $PATTERN"
    echo "[DEBUG] Input file: $INPUT_FILE"
    echo "[DEBUG] Output file: $OUTPUT_FILE"
    echo "[DEBUG] Detected delimiter: [$DELIM]"
    echo "[DEBUG] Output delimiter: [$OUT_DELIM]"
    echo "[DEBUG] Report directory: $REPORT_DIR"
fi

# Pattern 1
if [ "$PATTERN" = "p1" ]; then
    awk -F"$DELIM" -v out_delim="$OUT_DELIM" -v use_display="$USE_DISPLAY" 'function trim(s){gsub(/^[ 	]+|[ 	]+$/, "", s); return s;} NR>1 && NF>0 {ip=trim($2); cidr=trim($3); display=trim($5); city=trim($7); state=trim($14); if(ip==""||cidr==""){next;} combined=ip"/"cidr; loc=(use_display=="true"&&display!="")?display:(city!=""?city" "state:"no data"); print combined out_delim """loc""";}' "$INPUT_FILE" > "$REPORT_DIR/$OUTPUT_FILE"
fi

# Pattern 2
if [ "$PATTERN" = "p2" ]; then
    awk -F"$DELIM" -v out_delim="$OUT_DELIM" 'function trim(s){gsub(/^[ 	]+|[ 	]+$/, "", s); return s;} NR>1 && NF>0 {ip=trim($2); if(ip==""||ip!~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/){next;} city=trim($5); state=trim($6); type=trim($3); desc=trim($4); entry1=ip"/24"; entry2=(state!=""?city" "state:city); if(type==""){type="no data";} if(desc==""){desc="no data";} if(entry2~/ /){entry2="""entry2""";} if(desc~/ /){desc="""desc""";} print entry1 out_delim entry2 out_delim type out_delim desc;}' "$INPUT_FILE" > "$REPORT_DIR/$OUTPUT_FILE"
fi

# Pattern 3
if [ "$PATTERN" = "p3" ]; then
    awk -F"$DELIM" 'NR>1 && NF>0 {print $1"="$3}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_1${DATESTAMP}.txt"
    awk -F"$DELIM" 'NR>1 && NF>0 {print $1"="$4}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_2${DATESTAMP}.txt"
    awk -F"$DELIM" 'NR>1 && NF>0 {print $1"="$5}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_3${DATESTAMP}.txt"
    awk -F"$DELIM" 'NR>1 && NF>0 {gsub(/ /,"_",$6); print $1"="$6}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_4${DATESTAMP}.txt"
    awk -F"$DELIM" 'NR>1 && NF>0 {print $1"=""$7"""}' "$INPUT_FILE" > "$REPORT_DIR/IP_Metadata_Report_5${DATESTAMP}.txt"
fi

echo "Reports generated in directory: $REPORT_DIR"
