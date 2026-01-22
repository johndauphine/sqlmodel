#!/bin/bash
# =============================================================================
# 03-create-migration.sh
# Generate Alembic migration
# Idempotent: applies pending migrations first, skips if no schema changes
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
# Check for existing migrations and apply if needed
# -----------------------------------------------------------------------------
log "Checking migration status..."

EXISTING_MIGRATIONS=$(ls alembic/versions/*.py 2>/dev/null | wc -l || echo "0")
CURRENT=$(alembic current 2>/dev/null | grep -oE '^[a-f0-9]+' || echo "none")
HEAD=$(alembic heads 2>/dev/null | grep -oE '^[a-f0-9]+' || echo "none")

log "Existing migration files: $EXISTING_MIGRATIONS"
log "Current database revision: $CURRENT"
log "Head revision: $HEAD"

# If there are existing migrations and we're not at head, apply them first
if [[ "$EXISTING_MIGRATIONS" -gt 0 && "$CURRENT" != "$HEAD" && "$HEAD" != "none" ]]; then
    log "Pending migrations detected. Applying existing migrations first..."
    alembic upgrade head
    CURRENT=$(alembic current 2>/dev/null | grep -oE '^[a-f0-9]+' || echo "none")
    log "Now at revision: $CURRENT"
fi

# -----------------------------------------------------------------------------
# Check if schema changes are needed
# -----------------------------------------------------------------------------
MIGRATION_MSG="${1:-Initial schema migration}"

log "Checking for schema differences..."

# Use alembic to check for differences without creating a migration
TEMP_OUTPUT=$(mktemp)
set +e  # Temporarily disable exit on error
alembic revision --autogenerate -m "$MIGRATION_MSG" 2>&1 | tee "$TEMP_OUTPUT"
ALEMBIC_EXIT_CODE=$?
set -e

# Check if there were no changes
if grep -q "No changes in schema detected" "$TEMP_OUTPUT"; then
    log "No schema changes detected - database is in sync with models"
    rm -f "$TEMP_OUTPUT"
    deactivate
    log "Step 3 complete: No migration needed (already in sync)"
    exit 0
fi

# Check if alembic failed for another reason
if [[ $ALEMBIC_EXIT_CODE -ne 0 ]]; then
    echo "ERROR: Alembic revision failed"
    cat "$TEMP_OUTPUT"
    rm -f "$TEMP_OUTPUT"
    deactivate
    exit 1
fi

rm -f "$TEMP_OUTPUT"

# -----------------------------------------------------------------------------
# Find the generated migration file
# -----------------------------------------------------------------------------
MIGRATION_FILE=$(ls -t alembic/versions/*.py 2>/dev/null | head -1)

if [[ -z "$MIGRATION_FILE" ]]; then
    echo "ERROR: No migration file found"
    deactivate
    exit 1
fi

log "Migration file: $MIGRATION_FILE"

# -----------------------------------------------------------------------------
# Check if migration is empty (no actual changes)
# -----------------------------------------------------------------------------
HAS_OPERATIONS=$(grep -c "op\.\(create_table\|drop_table\|add_column\|drop_column\|create_index\|drop_index\|alter_column\)" "$MIGRATION_FILE" || true)

if [[ "$HAS_OPERATIONS" -eq 0 ]]; then
    log "Migration is empty (no schema changes) - removing"
    rm -f "$MIGRATION_FILE"
    deactivate
    log "Step 3 complete: No migration needed (already in sync)"
    exit 0
fi

# -----------------------------------------------------------------------------
# Remove collations (if any)
# -----------------------------------------------------------------------------
COLLATION_COUNT_BEFORE=$(grep -c "collation=" "$MIGRATION_FILE" || true)

if [[ "$COLLATION_COUNT_BEFORE" -gt 0 ]]; then
    log "Found $COLLATION_COUNT_BEFORE collation reference(s) to remove..."

    # Remove collation parameter from column definitions
    sed -i "s/, collation='[^']*'//g" "$MIGRATION_FILE"
    sed -i "s/collation='[^']*', //g" "$MIGRATION_FILE"
    # Handle sa.Unicode(collation='...') -> sa.Unicode()
    sed -i "s/(collation='[^']*')/()/g" "$MIGRATION_FILE"

    # Verify removal
    COLLATION_COUNT_AFTER=$(grep -c "collation=" "$MIGRATION_FILE" || true)

    if [[ "$COLLATION_COUNT_AFTER" -gt 0 ]]; then
        echo "WARNING: $COLLATION_COUNT_AFTER collation reference(s) could not be removed"
        echo "Please manually review: $MIGRATION_FILE"
    else
        log "All collations removed successfully"
    fi
fi

# -----------------------------------------------------------------------------
# Display migration summary
# -----------------------------------------------------------------------------
log "Migration created successfully"
log "File: $MIGRATION_FILE"

# Count operations
CREATE_TABLE_COUNT=$(grep -c "op.create_table" "$MIGRATION_FILE" || true)
CREATE_INDEX_COUNT=$(grep -c "op.create_index" "$MIGRATION_FILE" || true)

log "Summary: $CREATE_TABLE_COUNT table(s), $CREATE_INDEX_COUNT index(es)"

deactivate
log "Step 3 complete: Migration created"
