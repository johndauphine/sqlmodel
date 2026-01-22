#!/bin/bash
# =============================================================================
# 03-create-migration.sh
# Generate Alembic migration and remove MSSQL-specific collations
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Load configuration
# -----------------------------------------------------------------------------
if [[ ! -f "$SCRIPT_DIR/config.env" ]]; then
    echo "ERROR: config.env not found"
    exit 1
fi

source "$SCRIPT_DIR/config.env"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# -----------------------------------------------------------------------------
# Validate prerequisites
# -----------------------------------------------------------------------------
log "Checking prerequisites..."

if [[ ! -d "$WORK_DIR/alembic" ]]; then
    echo "ERROR: Alembic not initialized in $WORK_DIR"
    echo "Please run 02-init-alembic.sh first"
    exit 1
fi

cd "$WORK_DIR"

# -----------------------------------------------------------------------------
# Activate virtual environment
# -----------------------------------------------------------------------------
log "Activating virtual environment..."
source venv/bin/activate

# -----------------------------------------------------------------------------
# Generate migration
# -----------------------------------------------------------------------------
MIGRATION_MSG="${1:-Initial schema migration from MSSQL}"

log "Generating migration: $MIGRATION_MSG"
alembic revision --autogenerate -m "$MIGRATION_MSG"

# -----------------------------------------------------------------------------
# Find the generated migration file
# -----------------------------------------------------------------------------
MIGRATION_FILE=$(ls -t alembic/versions/*.py 2>/dev/null | head -1)

if [[ -z "$MIGRATION_FILE" ]]; then
    echo "ERROR: No migration file found"
    exit 1
fi

log "Migration file: $MIGRATION_FILE"

# -----------------------------------------------------------------------------
# Remove MSSQL-specific collations
# -----------------------------------------------------------------------------
log "Removing MSSQL-specific collations..."

# Count collations before removal
COLLATION_COUNT_BEFORE=$(grep -c "collation=" "$MIGRATION_FILE" || echo "0")

if [[ "$COLLATION_COUNT_BEFORE" -gt 0 ]]; then
    log "Found $COLLATION_COUNT_BEFORE collation reference(s) to remove"

    # Remove collation parameter from column definitions
    sed -i "s/, collation='[^']*'//g" "$MIGRATION_FILE"
    sed -i "s/collation='[^']*', //g" "$MIGRATION_FILE"
    # Handle sa.Unicode(collation='...') -> sa.Unicode()
    sed -i "s/(collation='[^']*')/()/g" "$MIGRATION_FILE"

    # Verify removal
    COLLATION_COUNT_AFTER=$(grep -c "collation=" "$MIGRATION_FILE" || echo "0")

    if [[ "$COLLATION_COUNT_AFTER" -gt 0 ]]; then
        echo "WARNING: $COLLATION_COUNT_AFTER collation reference(s) could not be removed"
        echo "Please manually review: $MIGRATION_FILE"
    else
        log "All collations removed successfully"
    fi
else
    log "No collations found (none to remove)"
fi

# -----------------------------------------------------------------------------
# Display migration summary
# -----------------------------------------------------------------------------
log "Migration created successfully"
log "File: $MIGRATION_FILE"

# Count operations
CREATE_TABLE_COUNT=$(grep -c "op.create_table" "$MIGRATION_FILE" || echo "0")
CREATE_INDEX_COUNT=$(grep -c "op.create_index" "$MIGRATION_FILE" || echo "0")

log "Summary: $CREATE_TABLE_COUNT table(s), $CREATE_INDEX_COUNT index(es)"

deactivate
log "Step 3 complete: Migration created"
