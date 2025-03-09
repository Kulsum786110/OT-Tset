#!/usr/bin/env bash
set -euo pipefail

# Optional: log output to a file
LOG_FILE="sql_execution_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Ensure CONNECTION_STRING is provided
if [[ -z "${CONNECTION_STRING:-}" ]]; then
    echo "Error: CONNECTION_STRING environment variable is not set."
    exit 1
fi

# Expected format:
# sqlserver://nsnsqlmidev102.a51a56ea8c79.database.windows.net:1433;databaseName=ECM_OT;encrypt=true;trust
connection="${CONNECTION_STRING#sqlserver://}"  # Remove the 'sqlserver://' prefix
server_with_port="${connection%%;*}"              # Get the server and port part
server="$server_with_port"                        # e.g., nsnsqlmidev102.a51a56ea8c79.database.windows.net:1433

# Extract database name by iterating over semicolon-separated parts
database=""
IFS=';' read -ra parts <<< "$connection"
for part in "${parts[@]}"; do
    if [[ $part == databaseName=* ]]; then
        database="${part#databaseName=}"
    fi
done

if [[ -z "$database" ]]; then
    echo "Error: databaseName not found in connection string."
    exit 1
fi

echo "Using connection parameters:"
echo "Server: $server"
echo "Database: $database"

# Directory containing SQL scripts (adjust if necessary)
SQL_SCRIPTS_DIR="./sqlscripts"
shopt -s nullglob
sql_files=("$SQL_SCRIPTS_DIR"/*.sql)
if [ ${#sql_files[@]} -eq 0 ]; then
    echo "No SQL scripts found in $SQL_SCRIPTS_DIR to execute."
    exit 0
fi

echo "Executing SQL scripts..."
for sql_file in "${sql_files[@]}"; do
    echo "Running script: $sql_file"
    # Using -G for Azure AD integrated authentication,
    # -N to enable encryption and -C to trust the server certificate.
    sqlcmd -S "$server" -d "$database" -G -N -C -i "$sql_file"
    echo "Completed: $sql_file"
done

echo "All SQL scripts executed successfully."
