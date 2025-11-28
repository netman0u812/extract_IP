README: extract_ip_csv.sh

Overview:
extract_ip_csv.sh is a multi-pattern IP report generator that processes CSV or TSV files and creates structured reports. It supports three patterns:

- -p1: IP/CIDR + Location (with optional display name)
- -p2: IP/CIDR + City/State + Type + Description (only if Column2 has valid IPv4)
- -p3: Generates 5 reports mapping Subnet to Realm, BU, Type, Location, Description

The script is macOS and Linux compatible, POSIX-safe, and includes features like auto-detecting delimiters, ignoring blank lines, and creating separate output directories for each pattern.

Features:
- Auto-detects input delimiter (tab, comma, semicolon)
- Ignores blank lines
- Creates separate directories for each pattern:
  - report_p1_<date>
  - report_p2_<date>
  - report_p3_<date>
- Adds timestamp to output files if requested
- Includes -examples flag for quick CLI usage examples
- Includes -v flag to show script version
- Debug mode (-d) prints key events and processing steps to stdout

Usage:
./extract_ip_csv.sh -p1|-p2|-p3 [options] input.csv [output.txt]

Patterns:
- -p1 : IP/CIDR from Column2 + Column3 + Location
- -p2 : IP/CIDR + City/State + Type + Description (only if Column2 has valid IPv4)
- -p3 : Generate 5 reports mapping Subnet to Realm, BU, Type, Location, Description

Options:
- -dl <delimiter>   Input delimiter (auto-detect if not set)
- -ds | -dt | -dc   Output delimiter: space | tab | comma (for p1/p2)
- --use-display     Use Display Name for location in Pattern 1
- -d                Debug mode (prints events to stdout)
- -t                Append timestamp to output file(s)
- -examples         Show CLI usage examples
- -v                Show script version
- -h                Show help

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

Output:
- Pattern 1 → report_p1_<date>/IP_Prefix_report.txt
- Pattern 2 → report_p2_<date>/IP_Prefix_report.txt
- Pattern 3 → report_p3_<date>/IP_Metadata_Report_1_<date>.txt … Report_5_<date>.txt
