#!/usr/bin/env bash
# extract_csv.sh - Multi-pattern IP report generator

show_help() {
cat <<EOF
Usage:
 ./extract_csv.sh -p1|-p2 [options] input.csv [output.txt]

Patterns:
 -p1 : IP/CIDR from Column2 + Column3 + Location
 -p2 : IP/CIDR + City/State + Type + Description (only if Column2 has valid IPv4)

Options:
 -dl <delimiter>   Input delimiter (auto-detect if not set)
 -ds | -dt | -dc   Output delimiter: space | tab | comma
 --use-display     Use Display Name for location in Pattern 1
 -d                Debug mode
 -t                Append timestamp to output file
 -h                Show help
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
while [[ $# -gt 0 ]]; do
 case "$1" in
 -p1) PATTERN="p1"; shift ;;
 -p2) PATTERN="p2"; shift ;;
 -dl) DELIM="$2"; shift 2 ;;
 -ds) OUT_DELIM=" "; shift ;;
 -dt) OUT_DELIM=$'\t'; shift ;;
 -dc) OUT_DELIM=","; shift ;;
 --use-display) USE_DISPLAY=true; shift ;;
 -d) DEBUG=true; shift ;;
 -t) TIMESTAMP=true; shift ;;
 -h|--help) show_help ;;
 *)
   if [[ -z "$INPUT_FILE" ]]; then INPUT_FILE="$1"
   elif [[ -z "$OUTPUT_FILE" ]]; then OUTPUT_FILE="$1"
   fi
   shift ;;
 esac
done

# Validate
if [[ -z "$PATTERN" || -z "$INPUT_FILE" ]]; then
 echo "Error: Missing required arguments."; show_help
fi
if [[ ! -f "$INPUT_FILE" ]]; then
 echo "Error: Input file not found."; exit 1
fi
if [[ -z "$OUTPUT_FILE" ]]; then OUTPUT_FILE="IP_Prefix_report.txt"; fi
if $TIMESTAMP; then OUTPUT_FILE="${OUTPUT_FILE%.txt}_$(date +'%d-%m_%H-%M').txt"; fi

# Auto-detect delimiter
if [[ -z "$DELIM" ]]; then
 first_line=$(head -n 1 "$INPUT_FILE")
 if [[ "$first_line" == *$'\t'* ]]; then DELIM=$'\t'
 elif [[ "$first_line" == *";"* ]]; then DELIM=";"
 else DELIM=","
 fi
fi

> "$OUTPUT_FILE"

# Pattern 1: IP/CIDR + Location
if [[ "$PATTERN" == "p1" ]]; then
 awk -F"$DELIM" -v out_delim="$OUT_DELIM" -v use_display="$USE_DISPLAY" -v debug="$DEBUG" '
 function trim(s){gsub(/^[ \t]+|[ \t]+$/, "", s); return s;}
 BEGIN { row_count=0; skip_count=0; }
 NR>1 {
   ip=trim($2); cidr=trim($3); display=trim($5);
   city=trim($7); state=trim($14);
   if(ip=="" || cidr==""){skip_count++; next;}
   combined=ip"/"cidr;
   loc=(use_display=="true" && display!="") ? display : (city!="" ? city" "state : "no data");
   print combined out_delim "\""loc"\"";
   row_count++;
 }
 END {
   if(debug=="true"){
     print "Processed rows: " row_count > "/dev/stderr";
     print "Skipped rows: " skip_count > "/dev/stderr";
   }
 }
 ' "$INPUT_FILE" > "$OUTPUT_FILE"
fi

# Pattern 2: IP/CIDR + City/State + Type + Description (only if Column2 has IPv4)
if [[ "$PATTERN" == "p2" ]]; then
 awk -F"$DELIM" -v out_delim="$OUT_DELIM" -v debug="$DEBUG" '
 function trim(s){gsub(/^[ \t]+|[ \t]+$/, "", s); return s;}
 BEGIN { row_count=0; skip_count=0; }
 NR>1 {
   ip=trim($2);
   if(ip=="" || ip !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/){skip_count++; next;}
   city=trim($5); state=trim($6);
   type=trim($3); desc=trim($4);
   entry1=ip"/24";
   entry2=(state!=""?city" "state:city);
   if(type==""){type="no data";}
   if(desc==""){desc="no data";}
   if(entry2~/ /){entry2="\""entry2"\"";}
   if(desc~/ /){desc="\""desc"\"";}
   print entry1 out_delim entry2 out_delim type out_delim desc;
   row_count++;
 }
 END {
   if(debug=="true"){
     print "Processed rows: " row_count > "/dev/stderr";
     print "Skipped rows (invalid IP): " skip_count > "/dev/stderr";
   }
 }
 ' "$INPUT_FILE" > "$OUTPUT_FILE"
fi

if $DEBUG; then
 echo "Pattern applied: $PATTERN"
 echo "Detected input delimiter: [$DELIM]"
 echo "Output delimiter: [$OUT_DELIM]"
 echo "Output file: $OUTPUT_FILE"
fi


