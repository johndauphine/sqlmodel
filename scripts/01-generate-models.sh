#!/bin/bash
# =============================================================================
# 01-generate-models.sh
# Generate SQLAlchemy models from PostgreSQL using sqlacodegen
# Idempotent: skips if models.py already exists
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
# Check if models.py already exists (idempotent)
# -----------------------------------------------------------------------------
if [[ -f "$WORK_DIR/models.py" ]]; then
    TABLE_COUNT=$(grep -c "^class " "$WORK_DIR/models.py" || echo "0")
    log "models.py already exists with $TABLE_COUNT table(s) - skipping generation"
    log "To regenerate, delete $WORK_DIR/models.py first"
    log "Step 1 complete: Models already exist"
    exit 0
fi

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
log "Installing sqlacodegen and psycopg2-binary..."
pip install --quiet --upgrade pip
pip install --quiet sqlacodegen psycopg2-binary

# -----------------------------------------------------------------------------
# Build connection string
# -----------------------------------------------------------------------------
ENCODED_PASSWORD=$(urlencode "$SOURCE_PG_PASSWORD")
SOURCE_URL="postgresql+psycopg2://${SOURCE_PG_USER}:${ENCODED_PASSWORD}@${SOURCE_PG_HOST}:${SOURCE_PG_PORT}/${SOURCE_PG_DATABASE}"

log "Source PostgreSQL connection: ${SOURCE_PG_USER}@${SOURCE_PG_HOST}:${SOURCE_PG_PORT}/${SOURCE_PG_DATABASE}"

# -----------------------------------------------------------------------------
# Build sqlacodegen command
# -----------------------------------------------------------------------------
SQLACODEGEN_CMD="sqlacodegen '$SOURCE_URL' --schemas $SOURCE_PG_SCHEMA --outfile models.py"

# Add --tables flag if not migrating all tables
if [[ "$TABLES" != "all" ]]; then
    SQLACODEGEN_CMD="sqlacodegen '$SOURCE_URL' --schemas $SOURCE_PG_SCHEMA --tables $TABLES --outfile models.py"
    log "Generating models for tables: $TABLES"
else
    log "Generating models for all tables in schema: $SOURCE_PG_SCHEMA"
fi

# -----------------------------------------------------------------------------
# Derive target schema name: dw__<database>__<schema> (lowercase)
# -----------------------------------------------------------------------------
TARGET_SCHEMA="dw__${SOURCE_PG_DATABASE,,}__${SOURCE_PG_SCHEMA,,}"
log "Target PostgreSQL schema: $TARGET_SCHEMA"

# -----------------------------------------------------------------------------
# Generate models
# -----------------------------------------------------------------------------
log "Running sqlacodegen..."
eval $SQLACODEGEN_CMD

if [[ ! -f "models.py" ]]; then
    echo "ERROR: Failed to generate models.py"
    exit 1
fi

# -----------------------------------------------------------------------------
# Transform to lowercase and update schema
# -----------------------------------------------------------------------------
log "Transforming identifiers to lowercase..."

python3 << PYTHON_SCRIPT
import re

with open('models.py', 'r') as f:
    content = f.read()

# Update schema from source to target
content = re.sub(r"'schema': '[^']*'", "'schema': '$TARGET_SCHEMA'", content)

# Convert table names to lowercase: __tablename__ = 'TableName' -> __tablename__ = 'tablename'
content = re.sub(
    r"__tablename__ = '([^']+)'",
    lambda m: f"__tablename__ = '{m.group(1).lower()}'",
    content
)

# Convert constraint names to lowercase: name='PK_TableName__Id' -> name='pk_tablename__id'
content = re.sub(
    r"name='([^']+)'",
    lambda m: f"name='{m.group(1).lower()}'",
    content
)

# Convert column references in PrimaryKeyConstraint to lowercase
# PrimaryKeyConstraint('Id', ...) -> PrimaryKeyConstraint('id', ...)
content = re.sub(
    r"PrimaryKeyConstraint\('([^']+)'",
    lambda m: f"PrimaryKeyConstraint('{m.group(1).lower()}'",
    content
)

# Convert column names in mapped_column to lowercase identifiers
# This handles: Mapped[...] = mapped_column(...) patterns
# The actual column names are the Python attribute names, which we'll keep as-is
# but we need to ensure the database sees lowercase names

# Add explicit column name for each mapped_column to force lowercase in DB
lines = content.split('\n')
new_lines = []
for line in lines:
    # Match lines like: ColumnName: Mapped[type] = mapped_column(...)
    match = re.match(r'^(\s+)(\w+): (Mapped\[.+\]) = mapped_column\((.*)$', line)
    if match:
        indent, col_name, type_hint, rest = match.groups()
        col_lower = col_name.lower()
        # Check if there's already a column name specified
        if not rest.strip().startswith("'"):
            # Add lowercase column name as first argument
            line = f"{indent}{col_name}: {type_hint} = mapped_column('{col_lower}', {rest}"
    new_lines.append(line)

content = '\n'.join(new_lines)

with open('models.py', 'w') as f:
    f.write(content)

print("Transformation complete")
PYTHON_SCRIPT

TABLE_COUNT=$(grep -c "^class " models.py || echo "0")
log "SUCCESS: Generated models.py with $TABLE_COUNT table(s)"
log "Output: $WORK_DIR/models.py"

deactivate
log "Step 1 complete: Models generated"
