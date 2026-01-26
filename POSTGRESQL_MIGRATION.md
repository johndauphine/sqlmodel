# PostgreSQL Schema Migration Guide

This guide explains the PostgreSQL-to-PostgreSQL schema migration process in detail.

## Migration Overview

The migration scripts copy a database schema from a source PostgreSQL database to a target PostgreSQL database with:
- Lowercase table and column names
- A derived schema name: `dw__<database>__<schema>`

## Architecture

```
Source PostgreSQL          Target PostgreSQL
┌──────────────────┐      ┌──────────────────────────────┐
│ StackOverflow2010│      │ stackoverflow                │
│ ├── dbo          │  =>  │ ├── dw__stackoverflow2010__dbo│
│ │   ├── Users    │      │ │   ├── users                │
│ │   ├── Posts    │      │ │   ├── posts                │
│ │   └── Comments │      │ │   └── comments             │
└──────────────────┘      └──────────────────────────────┘
```

## Migration Pipeline

### Step 1: Generate Models (`01-generate-models.sh`)

Models are **always regenerated** from source to capture any schema changes. Uses sqlacodegen to reverse-engineer the source database:

```bash
sqlacodegen 'postgresql+psycopg2://user:pass@host:port/database' \
  --schemas dbo \
  --tables Users,Posts,Comments \
  --outfile models.py
```

The script then transforms:
- Schema name to `dw__<database>__<schema>`
- Table names to lowercase
- Column names to lowercase
- Constraint names to lowercase

### Step 2: Initialize Alembic (`02-init-alembic.sh`)

- Creates Python virtual environment
- Installs Alembic and psycopg2-binary
- Initializes Alembic configuration
- Updates `alembic.ini` with target database URL
- Updates `env.py` to import models
- Creates target schema in PostgreSQL

### Step 3: Create Migration (`03-create-migration.sh`)

- Checks for pending migrations and applies them first
- Runs `alembic revision --autogenerate`
- Detects and removes empty migrations
- Removes any collation references (for cross-database compatibility)

### Step 4: Apply Migration (`04-apply-migration.sh`)

- Generates DDL SQL file for review
- Applies migration with `alembic upgrade head`
- Verifies tables were created

### Step 5: Rollback (`05-rollback.sh`)

Options:
```bash
./05-rollback.sh              # Rollback all migrations
./05-rollback.sh -1           # Rollback one revision
./05-rollback.sh base yes     # Rollback all and drop schema
./05-rollback.sh <revision>   # Rollback to specific revision
```

## Configuration Reference

### config.env

```bash
# Source Database
SOURCE_PG_HOST=localhost      # Source PostgreSQL host
SOURCE_PG_PORT=5432           # Source PostgreSQL port
SOURCE_PG_USER=postgres       # Source database user
SOURCE_PG_PASSWORD=password   # Source database password
SOURCE_PG_DATABASE=SourceDB   # Source database name
SOURCE_PG_SCHEMA=dbo          # Source schema to migrate

# Target Database
TARGET_PG_HOST=localhost      # Target PostgreSQL host
TARGET_PG_PORT=5432           # Target PostgreSQL port
TARGET_PG_USER=postgres       # Target database user
TARGET_PG_PASSWORD=password   # Target database password
TARGET_PG_DATABASE=TargetDB   # Target database name

# Migration Settings
TABLES=all                    # "all" or comma-separated list
WORK_DIR=./migration_workspace
```

### Table Selection

Migrate specific tables:
```bash
TABLES=Users,Posts,Comments
```

Migrate all tables:
```bash
TABLES=all
```

## Generated Files

### models.py

SQLAlchemy 2.0 models with:
- Generation timestamp header
- `Mapped` type annotations
- Lowercase column names in database
- PascalCase Python attribute names

```python
# =============================================================================
# Auto-generated SQLAlchemy models
# Generated: 2026-01-26 17:34:43
# Source: StackOverflow2010.dbo
# Target: dw__stackoverflow2010__dbo
# Tables: Users,Posts
# =============================================================================

class Users(Base):
    __tablename__ = 'users'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='pk_users_id'),
        {'schema': 'dw__stackoverflow2010__dbo'}
    )

    Id: Mapped[int] = mapped_column('id', Integer, Identity(), primary_key=True)
    DisplayName: Mapped[str] = mapped_column('displayname', VARCHAR(40), nullable=False)
```

Previous versions are automatically backed up as `models_<timestamp>.py.bak`.

### migration.sql

Generated DDL for review:

```sql
BEGIN;

CREATE TABLE dw__stackoverflow2010__dbo.users (
    id SERIAL NOT NULL,
    displayname VARCHAR(40) NOT NULL,
    reputation INTEGER NOT NULL,
    CONSTRAINT pk_users_id PRIMARY KEY (id)
);

COMMIT;
```

## Schema Change Detection

The pipeline automatically detects source schema changes:

| Scenario | Behavior |
|----------|----------|
| Source unchanged | Models regenerated, no migration needed |
| New table added | Migration creates the table |
| Column added | Migration adds the column |
| Column removed | Migration drops the column |
| Already at head | Skip apply |

Models are always regenerated from source (~3-5 seconds) to ensure changes are captured. Alembic then compares models against the target and creates incremental migrations.

### Example: Handling Schema Changes

```bash
# Add column to source
psql -d SourceDB -c "ALTER TABLE dbo.Users ADD COLUMN Email VARCHAR(100)"

# Run migration - automatically detects the change
./scripts/migrate-all.sh
# Output: "Detected added column 'dw__sourcedb__dbo.users.email'"
```

## Troubleshooting

### Connection refused

Check database is running and accessible:
```bash
psql -h $SOURCE_PG_HOST -p $SOURCE_PG_PORT -U $SOURCE_PG_USER -d $SOURCE_PG_DATABASE
```

### Schema does not exist

The script creates the schema automatically. If it fails:
```bash
psql -h $TARGET_PG_HOST -p $TARGET_PG_PORT -U $TARGET_PG_USER -d $TARGET_PG_DATABASE \
  -c "CREATE SCHEMA IF NOT EXISTS dw__stackoverflow2010__dbo;"
```

### Permission denied

Ensure the target user has CREATE privileges:
```sql
GRANT CREATE ON DATABASE targetdb TO postgres;
```

### Password special characters

URL-encode special characters in passwords:
- `@` becomes `%40`
- `#` becomes `%23`
- `%` becomes `%25`

## Data Migration

These scripts handle **schema migration only**. For data migration, use:
- `pg_dump` / `pg_restore`
- Foreign Data Wrappers (FDW)
- Custom ETL scripts
- Data migration tools

Example with pg_dump:
```bash
# Export data from source
pg_dump -h source -U postgres -d SourceDB --data-only -t 'dbo.*' > data.sql

# Import to target (adjust schema names in SQL)
psql -h target -U postgres -d TargetDB < data.sql
```

## Extending the Migration

### Adding Foreign Keys

Edit `models.py` after generation:
```python
from sqlalchemy import ForeignKey
from sqlalchemy.orm import relationship

class Posts(Base):
    # ... existing columns ...
    OwnerUserId: Mapped[Optional[int]] = mapped_column(
        'owneruserid',
        Integer,
        ForeignKey('dw__stackoverflow2010__dbo.users.id')
    )
    owner = relationship('Users', back_populates='posts')
```

Then create a new migration:
```bash
cd scripts/migration_workspace
source venv/bin/activate
alembic revision --autogenerate -m "Add foreign keys"
alembic upgrade head
```

### Adding Indexes

Create a custom migration:
```bash
alembic revision -m "Add indexes"
```

Edit the migration file:
```python
def upgrade():
    op.create_index('idx_posts_owneruserid', 'posts', ['owneruserid'],
                    schema='dw__stackoverflow2010__dbo')

def downgrade():
    op.drop_index('idx_posts_owneruserid', 'posts',
                  schema='dw__stackoverflow2010__dbo')
```
