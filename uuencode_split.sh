
#!/usr/bin/env bash
#
# uuencode_split.sh
#
# SUMMARY:
# This script provides two main functions:
# 1. Encode Mode:
#    - Uuencode an input file and split it into chunks (default 20MB or custom size).
#    - Chunks are named sequentially: <uuencoded_file>-1, <uuencoded_file>-2, ...
# 2. Reassemble Mode:
#    - Concatenate chunks back into the original uuencoded file and uudecode it.
#
# FEATURES:
# - Supports custom chunk size via -s (e.g., 50M, 1G).
# - Displays estimated chunk count if -s is used.
# - Debug mode (-d) prints all steps and commands.
# - Graceful termination on Ctrl-C.
# - Cross-platform (macOS and Linux).
#
# USAGE:
#   Encode:    ./uuencode_split.sh -f <input_file> [-n <uuencoded_file>] [-s <chunk_size>] [-d]
#   Reassemble:./uuencode_split.sh -r <uuencoded_file> [-d]
#

set -e

CHUNK_SIZE=$((20 * 1024 * 1024)) # Default chunk size: 20MB
DEFAULT_OUTPUT="encoded_file.uu"
DEBUG=false

# Trap Ctrl-C for early termination
trap 'echo "Process interrupted by user. Exiting..."; exit 130' INT

# ---------------------------
# Function: show_help
# Displays usage instructions and examples.
# ---------------------------
show_help() {
  cat << EOF
Usage:
  Encode & Split:
    $0 -f <input_file> [-n <uuencoded_file>] [-s <chunk_size>] [-d] [-h]

  Reassemble & Decode:
    $0 -r <uuencoded_file> [-d] [-h]

Options:
  -f    Input file to uuencode (required for encoding)
  -n    Name of the uuencoded output file (optional, default: $DEFAULT_OUTPUT)
  -s    Custom chunk size (e.g., 10M, 50M, 1G). Default: 20M
  -r    Reassemble chunks and uudecode (requires base uuencoded filename)
  -d    Debug mode (prints all steps and commands to stdout)
  -h    Show this help message

Description:
  Encode Mode:
    Uuencodes the input file and splits the uuencoded file into chunks.
    Chunks are named as:
      <uuencoded_file>-1, <uuencoded_file>-2, ...

  Reassemble Mode:
    Joins all chunks back into the uuencoded file and uudecodes it to restore
    the original file.

Examples:
  Encode:
    $0 -f myfile.zip -n myfile.uu -s 50M
    $0 -f myfile.zip   # uses default name: $DEFAULT_OUTPUT

  Reassemble:
    $0 -r myfile.uu
EOF
}

# ---------------------------
# Function: log
# Prints debug messages if debug mode is enabled.
# ---------------------------
log() {
  if $DEBUG; then
    echo "[DEBUG] $*"
  fi
}

# ---------------------------
# Parse arguments
# ---------------------------
while getopts "f:n:r:s:dh" opt; do
  case $opt in
    f) INPUT_FILE="$OPTARG" ;;
    n) OUTPUT_FILE="$OPTARG" ;;
    r) REASSEMBLE_FILE="$OPTARG" ;;
    s) CUSTOM_SIZE="$OPTARG" ;;
    d) DEBUG=true ;;
    h) show_help; exit 0 ;;
    *) show_help; exit 1 ;;
  esac
done

# ---------------------------
# Handle custom chunk size
# ---------------------------
if [[ -n "$CUSTOM_SIZE" ]]; then
  if command -v numfmt >/dev/null 2>&1; then
    CHUNK_SIZE=$(numfmt --from=iec "$CUSTOM_SIZE")
  else
    # Manual conversion for macOS or systems without numfmt
    case "$CUSTOM_SIZE" in
      *K) CHUNK_SIZE=$(( ${CUSTOM_SIZE%K} * 1024 )) ;;
      *M) CHUNK_SIZE=$(( ${CUSTOM_SIZE%M} * 1024 * 1024 )) ;;
      *G) CHUNK_SIZE=$(( ${CUSTOM_SIZE%G} * 1024 * 1024 * 1024 )) ;;
      *) CHUNK_SIZE=$CUSTOM_SIZE ;; # Assume raw bytes if no suffix
    esac
  fi
fi

# ---------------------------
# Reassemble Mode
# ---------------------------
if [[ -n "$REASSEMBLE_FILE" ]]; then
  log "Starting reassemble mode for $REASSEMBLE_FILE"
  if ! ls "${REASSEMBLE_FILE}-"* >/dev/null 2>&1; then
    echo "Error: No chunks found for $REASSEMBLE_FILE"
    exit 1
  fi
  log "Concatenating chunks..."
  cat "${REASSEMBLE_FILE}-"* > "$REASSEMBLE_FILE"
  log "Running uudecode..."
  uudecode "$REASSEMBLE_FILE"
  echo "Done! Original file restored."
  exit 0
fi

# ---------------------------
# Encode Mode
# ---------------------------
if [[ -z "$INPUT_FILE" ]]; then
  echo "Error: -f flag is required for encoding."
  show_help
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: Input file '$INPUT_FILE' does not exist."
  exit 1
fi

OUTPUT_FILE="${OUTPUT_FILE:-$DEFAULT_OUTPUT}"

# Estimate chunk count if custom size is used
if [[ -n "$CUSTOM_SIZE" ]]; then
  FILE_SIZE=$(stat -c%s "$INPUT_FILE" 2>/dev/null || stat -f%z "$INPUT_FILE")
  ESTIMATED=$(( (FILE_SIZE + CHUNK_SIZE - 1) / CHUNK_SIZE ))
  echo "Estimated chunks with size $CUSTOM_SIZE: $ESTIMATED"
fi

log "Uuencoding $INPUT_FILE to $OUTPUT_FILE"
uuencode "$INPUT_FILE" "$(basename "$INPUT_FILE")" > "$OUTPUT_FILE"

log "Splitting $OUTPUT_FILE into chunks of size $CHUNK_SIZE bytes"
split -b "$CHUNK_SIZE" "$OUTPUT_FILE" "${OUTPUT_FILE}-"

log "Renaming chunks..."
count=1
for chunk in "${OUTPUT_FILE}-"*; do
  mv "$chunk" "${OUTPUT_FILE}-${count}"
  log "Renamed $chunk to ${OUTPUT_FILE}-${count}"
  count=$((count + 1))
done

echo "Done! Created $((count - 1)) chunks."
