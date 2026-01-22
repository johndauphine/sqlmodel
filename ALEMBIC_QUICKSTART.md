# Alembic Quick Reference

This guide covers manual Alembic operations. For automated migrations, use the scripts in `scripts/`.

## Automated Migration (Recommended)

```bash
# Full migration pipeline
./scripts/migrate-all.sh

# Or run steps individually
./scripts/01-generate-models.sh
./scripts/02-init-alembic.sh
./scripts/03-create-migration.sh
./scripts/04-apply-migration.sh
```

## Manual Alembic Commands

### Setup

```bash
cd scripts/migration_workspace
source venv/bin/activate
```

### Check Status

```bash
# Current database revision
alembic current

# Migration history
alembic history --verbose

# Show pending migrations
alembic heads
```

### Apply Migrations

```bash
# Upgrade to latest
alembic upgrade head

# Upgrade by steps
alembic upgrade +1

# Upgrade to specific revision
alembic upgrade abc123

# Generate SQL without executing
alembic upgrade head --sql > migration.sql
```

### Rollback Migrations

```bash
# Downgrade by 1 step
alembic downgrade -1

# Downgrade to specific revision
alembic downgrade abc123

# Rollback all migrations
alembic downgrade base
```

### Create New Migration

```bash
# Auto-generate from model changes
alembic revision --autogenerate -m "Add new column"

# Create empty migration
alembic revision -m "Custom migration"
```

## Configuration Files

### alembic.ini

Database connection URL:
```ini
sqlalchemy.url = postgresql://user:password@host:port/database
```

**Note:** Escape `%` as `%%` in INI files.

### alembic/env.py

Model imports and metadata:
```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
from models import Base
target_metadata = Base.metadata
```

## Troubleshooting

### "Target database is not up to date"
```bash
alembic upgrade head
```

### "No module named 'psycopg2'"
```bash
pip install psycopg2-binary
```

### Check connection
```python
from sqlalchemy import create_engine
engine = create_engine('postgresql://...')
engine.connect()
```

## Best Practices

1. Always review auto-generated migrations before applying
2. Test migrations in development first
3. Keep migrations in version control
4. Use meaningful migration messages
5. Back up database before production migrations
