#!/bin/bash
# =============================================================================
# 01-generate-models.sh
# Generate SQLAlchemy models from MSSQL using sqlacodegen
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Load configuration
# -----------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_DIR/config.env" ]]; then
    echo "ERROR: config.env not found"
    echo "Please copy config.env.example to config.env and update with your values:"
    echo "  cp $SCRIPT_DIR/config.env.example $SCRIPT_DIR/config.env"
    exit 1
fi

source "$SCRIPT_DIR/config.env"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
urlencode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('$1', safe=''))"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# -----------------------------------------------------------------------------
# Validate prerequisites
# -----------------------------------------------------------------------------
log "Checking prerequisites..."

if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 is required but not installed"
    exit 1
fi

# -----------------------------------------------------------------------------
# Create working directory
# -----------------------------------------------------------------------------
log "Creating working directory: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# -----------------------------------------------------------------------------
# Set up Python virtual environment
# -----------------------------------------------------------------------------
if [[ ! -d "venv" ]]; then
    log "Creating Python virtual environment..."
    python3 -m venv venv
fi

log "Activating virtual environment..."
source venv/bin/activate

# -----------------------------------------------------------------------------
# Install dependencies
# -----------------------------------------------------------------------------
log "Installing sqlacodegen and pymssql..."
pip install --quiet --upgrade pip
pip install --quiet sqlacodegen pymssql

# -----------------------------------------------------------------------------
# Build connection string
# -----------------------------------------------------------------------------
ENCODED_PASSWORD=$(urlencode "$MSSQL_PASSWORD")
MSSQL_URL="mssql+pymssql://${MSSQL_USER}:${ENCODED_PASSWORD}@${MSSQL_HOST}:${MSSQL_PORT}/${MSSQL_DATABASE}"

log "MSSQL connection: ${MSSQL_USER}@${MSSQL_HOST}:${MSSQL_PORT}/${MSSQL_DATABASE}"

# -----------------------------------------------------------------------------
# Build sqlacodegen command
# -----------------------------------------------------------------------------
SQLACODEGEN_CMD="sqlacodegen '$MSSQL_URL' --schemas $MSSQL_SCHEMA --outfile models.py"

# Add --tables flag if not migrating all tables
if [[ "$TABLES" != "all" ]]; then
    SQLACODEGEN_CMD="sqlacodegen '$MSSQL_URL' --schemas $MSSQL_SCHEMA --tables $TABLES --outfile models.py"
    log "Generating models for tables: $TABLES"
else
    log "Generating models for all tables in schema: $MSSQL_SCHEMA"
fi

# -----------------------------------------------------------------------------
# Generate models
# -----------------------------------------------------------------------------
log "Running sqlacodegen..."
eval $SQLACODEGEN_CMD

if [[ -f "models.py" ]]; then
    TABLE_COUNT=$(grep -c "^class " models.py || echo "0")
    log "SUCCESS: Generated models.py with $TABLE_COUNT table(s)"
    log "Output: $WORK_DIR/models.py"
else
    echo "ERROR: Failed to generate models.py"
    exit 1
fi

deactivate
log "Step 1 complete: Models generated"
