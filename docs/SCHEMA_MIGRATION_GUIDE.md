# Schema Migration with Code Generation

A comprehensive guide to database schema migration using SQLAlchemy code generation and Alembic migrations.

## Table of Contents

1. [Introduction](#introduction)
2. [Why Code Generation?](#why-code-generation)
3. [Architecture Overview](#architecture-overview)
4. [The Migration Pipeline](#the-migration-pipeline)
5. [Benefits of This Approach](#benefits-of-this-approach)
6. [Comparison with Alternatives](#comparison-with-alternatives)
7. [Best Practices](#best-practices)
8. [Use Cases](#use-cases)

---

## Introduction

Schema migration is the process of transferring database structure (tables, columns, constraints, indexes) from one database to another. This toolkit uses a **code generation approach** where:

1. SQLAlchemy models are reverse-engineered from the source database
2. Models are transformed to meet target requirements (naming conventions, schema names)
3. Alembic generates and applies migrations to the target database

This approach provides a programmatic, version-controlled, and repeatable way to migrate schemas across PostgreSQL databases.

---

## Why Code Generation?

### The Problem with Manual Schema Migration

Traditional schema migration approaches have significant drawbacks:

| Approach | Problems |
|----------|----------|
| **Manual DDL scripts** | Error-prone, hard to maintain, no validation |
| **pg_dump/pg_restore** | All-or-nothing, limited transformation options |
| **GUI tools** | Not repeatable, no version control, manual effort |
| **Hand-written models** | Time-consuming, prone to drift from actual schema |

### The Code Generation Solution

Code generation with sqlacodegen solves these problems by:

```
Source Database ──► sqlacodegen ──► SQLAlchemy Models ──► Alembic ──► Target Database
                    (reverse       (Python code,         (version-
                     engineer)      transformable)        controlled
                                                          migrations)
```

**Key insight**: By generating SQLAlchemy models from the source, you get an accurate, programmatic representation of the schema that can be:
- Transformed with code (lowercase names, schema changes)
- Version controlled in git
- Used to generate incremental migrations
- Validated before deployment

---

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Migration Pipeline                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌───────────┐ │
│  │    Source    │    │  sqlacodegen │    │   Python     │    │  Alembic  │ │
│  │  PostgreSQL  │───►│  (reverse    │───►│  Transform   │───►│ Migration │ │
│  │   Database   │    │   engineer)  │    │   Script     │    │  Engine   │ │
│  └──────────────┘    └──────────────┘    └──────────────┘    └─────┬─────┘ │
│                                                                     │       │
│                                                                     ▼       │
│                                                              ┌───────────┐  │
│                                                              │  Target   │  │
│                                                              │ PostgreSQL│  │
│                                                              │ Database  │  │
│                                                              └───────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Source Database** → Contains the original schema to migrate
2. **sqlacodegen** → Introspects source and generates SQLAlchemy model code
3. **Transform Script** → Applies naming conventions and schema transformations
4. **Alembic** → Compares models to target, generates migration DDL
5. **Target Database** → Receives the migrated schema

### Generated Artifacts

```
migration_workspace/
├── models.py              # SQLAlchemy models (generated + transformed)
├── alembic.ini            # Alembic configuration
├── migration_*.sql        # Generated DDL for review
├── venv/                  # Isolated Python environment
└── alembic/
    ├── env.py             # Alembic environment (imports models)
    ├── script.py.mako     # Migration template
    └── versions/          # Version-controlled migrations
        └── abc123_initial_schema_migration.py
```

---

## The Migration Pipeline

### Step 1: Model Generation

**Script**: `01-generate-models.sh`

sqlacodegen connects to the source database and reverse-engineers SQLAlchemy models:

```bash
sqlacodegen 'postgresql://user:pass@host:port/database' \
  --schemas dbo \
  --tables Users,Posts \
  --outfile models.py
```

**What it produces**:
```python
class Users(Base):
    __tablename__ = 'Users'
    __table_args__ = {'schema': 'dbo'}

    Id: Mapped[int] = mapped_column(Integer, primary_key=True)
    DisplayName: Mapped[str] = mapped_column(String(40))
```

**Transformation applied**:
```python
class Users(Base):
    __tablename__ = 'users'  # lowercase
    __table_args__ = {'schema': 'dw__stackoverflow2010__dbo'}  # derived schema

    Id: Mapped[int] = mapped_column('id', Integer, primary_key=True)  # lowercase DB column
    DisplayName: Mapped[str] = mapped_column('displayname', String(40))
```

### Step 2: Alembic Initialization

**Script**: `02-init-alembic.sh`

Sets up the Alembic migration environment:

1. Creates Python virtual environment
2. Installs dependencies (alembic, psycopg2-binary)
3. Initializes Alembic directory structure
4. Configures target database connection
5. Creates target schema in PostgreSQL

**Key configuration** (alembic.ini):
```ini
sqlalchemy.url = postgresql://user:pass@host:port/database
```

**Environment setup** (env.py):
```python
from models import Base
target_metadata = Base.metadata
```

### Step 3: Migration Creation

**Script**: `03-create-migration.sh`

Alembic compares the SQLAlchemy models against the target database and generates a migration:

```bash
alembic revision --autogenerate -m "Initial schema migration"
```

**Generated migration**:
```python
def upgrade():
    op.create_table('users',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('displayname', sa.String(40), nullable=False),
        sa.PrimaryKeyConstraint('id', name='users_pkey'),
        schema='dw__stackoverflow2010__dbo'
    )

def downgrade():
    op.drop_table('users', schema='dw__stackoverflow2010__dbo')
```

### Step 4: Migration Application

**Script**: `04-apply-migration.sh`

Applies the migration to the target database:

```bash
# Generate DDL for review
alembic upgrade head --sql > migration.sql

# Apply migration
alembic upgrade head
```

### Step 5: Rollback (if needed)

**Script**: `05-rollback.sh`

Reverts migrations using Alembic's downgrade:

```bash
alembic downgrade -1      # Rollback one revision
alembic downgrade base    # Rollback all revisions
```

---

## Benefits of This Approach

### 1. Accuracy Through Automation

| Manual Approach | Code Generation Approach |
|-----------------|--------------------------|
| Human reads schema, writes DDL | Machine reads schema, generates code |
| Typos and omissions common | Exact representation of source |
| Hours of tedious work | Seconds to generate |

**Example**: A table with 50 columns and 10 constraints takes the same time to generate as a table with 2 columns.

### 2. Transformation Capabilities

Code generation produces Python code that can be programmatically transformed:

```python
# Lowercase all identifiers
content = re.sub(r"__tablename__ = '([^']+)'",
    lambda m: f"__tablename__ = '{m.group(1).lower()}'", content)

# Update schema references
content = re.sub(r"'schema': '[^']*'",
    f"'schema': '{target_schema}'", content)

# Transform foreign key references
content = re.sub(r"ForeignKeyConstraint\(\[([^\]]+)\], \[([^\]]+)\]",
    transform_fk, content)
```

This enables:
- Naming convention enforcement (lowercase, snake_case)
- Schema relocation (dbo → dw__database__schema)
- Constraint renaming
- Cross-database compatibility fixes

### 3. Version Control Integration

All artifacts are text files that work naturally with git:

```bash
git log --oneline alembic/versions/
# abc123 Add users and posts tables
# def456 Add indexes for performance
# ghi789 Add foreign key constraints
```

Benefits:
- **History**: See what changed and when
- **Collaboration**: Multiple developers can work on migrations
- **Rollback**: Revert to previous schema versions
- **Code review**: Review migrations before applying

### 4. Incremental Migrations

Alembic tracks what's been applied and only generates new changes:

```
First run:  Source has Users, Posts    → Migration creates both tables
Second run: Source adds Comments table → Migration creates only Comments
Third run:  No changes                 → No migration generated
```

This enables:
- **Continuous sync**: Keep target in sync with evolving source
- **Safe re-runs**: Idempotent operations
- **Selective updates**: Apply specific migrations

### 5. Pre-Deployment Validation

The generated DDL can be reviewed before execution:

```sql
-- migration_20240126.sql
BEGIN;

CREATE TABLE dw__stackoverflow2010__dbo.users (
    id SERIAL NOT NULL,
    displayname VARCHAR(40) NOT NULL,
    CONSTRAINT users_pkey PRIMARY KEY (id)
);

COMMIT;
```

This allows:
- DBA review of generated DDL
- Performance analysis of schema design
- Security audit of table structures
- Testing in staging environments

### 6. Relationship Preservation

Foreign key relationships are automatically detected and transformed:

**Source**:
```sql
ALTER TABLE dbo.Posts
ADD CONSTRAINT FK_Posts_Users
FOREIGN KEY (OwnerUserId) REFERENCES dbo.Users(Id);
```

**Generated model**:
```python
class Posts(Base):
    __table_args__ = (
        ForeignKeyConstraint(
            ['owneruserid'],
            ['dw__stackoverflow2010__dbo.users.id'],
            name='fk_posts_users'
        ),
    )
```

### 7. Type Safety and IDE Support

SQLAlchemy models provide:
- **Type hints**: `Mapped[int]`, `Mapped[Optional[str]]`
- **IDE autocomplete**: Navigate relationships, find usages
- **Static analysis**: Catch errors before runtime

```python
# IDE knows the types
user: Users = session.query(Users).first()
print(user.DisplayName)  # IDE autocompletes, type-checks
```

### 8. Cross-Platform Compatibility

The same models work across:
- Different PostgreSQL versions
- Development, staging, production environments
- Multiple target databases simultaneously

---

## Comparison with Alternatives

### vs. pg_dump/pg_restore

| Feature | pg_dump | Code Generation |
|---------|---------|-----------------|
| Speed | Fast for simple dumps | Moderate |
| Transformation | Limited (sed/awk) | Full Python power |
| Incremental | No (full dump) | Yes (Alembic tracking) |
| Version control | Binary/large files | Text/small files |
| Rollback | Restore from backup | Alembic downgrade |
| Validation | None | Model validation |

**Best for pg_dump**: One-time, full database clones without transformation.

**Best for code generation**: Ongoing sync with transformations, version control needs.

### vs. Schema Compare Tools (DataGrip, DBeaver)

| Feature | GUI Tools | Code Generation |
|---------|-----------|-----------------|
| Automation | Manual clicks | Fully scriptable |
| CI/CD integration | Difficult | Native |
| Repeatability | Depends on user | Guaranteed |
| Transformation | Limited | Unlimited |
| Cost | Often licensed | Open source |

**Best for GUI tools**: Ad-hoc comparisons, visual exploration.

**Best for code generation**: Automated pipelines, DevOps workflows.

### vs. Hand-Written SQLAlchemy Models

| Feature | Hand-Written | Generated |
|---------|--------------|-----------|
| Initial effort | High | Low |
| Accuracy | Prone to drift | Always accurate |
| Maintenance | Manual sync | Re-generate |
| Large schemas | Impractical | Trivial |

**Best for hand-written**: Greenfield projects, custom ORM logic.

**Best for generated**: Migrating existing schemas, keeping in sync with source.

---

## Best Practices

### 1. Always Review Generated Migrations

```bash
# Generate DDL first
alembic upgrade head --sql > migration.sql

# Review the SQL
cat migration.sql

# Then apply
alembic upgrade head
```

### 2. Use Meaningful Migration Messages

```bash
alembic revision --autogenerate -m "Add user authentication tables"
```

Not:
```bash
alembic revision --autogenerate -m "update"
```

### 3. Test Migrations in Staging First

```bash
# Apply to staging
TARGET_PG_DATABASE=staging ./scripts/migrate-all.sh

# Verify
psql -d staging -c "\dt schema.*"

# Then production
TARGET_PG_DATABASE=production ./scripts/migrate-all.sh
```

### 4. Keep Source and Target Schemas in Sync

Run migrations regularly to avoid large, risky changes:

```bash
# Weekly sync job
0 0 * * 0 /path/to/scripts/migrate-all.sh >> /var/log/migration.log 2>&1
```

### 5. Version Control Everything

```bash
git add alembic/versions/*.py
git commit -m "Add migration for new tables"
```

### 6. Use Idempotent Scripts

All scripts in this toolkit are idempotent:
- Safe to run multiple times
- Skip already-completed steps
- No duplicate migrations

### 7. Document Schema Transformations

Keep a record of transformations applied:

| Source | Target | Reason |
|--------|--------|--------|
| `dbo.Users` | `dw__db__dbo.users` | Data warehouse naming convention |
| `NVARCHAR` | `VARCHAR` | PostgreSQL compatibility |
| `IDENTITY` | `SERIAL` | PostgreSQL equivalent |

---

## Use Cases

### 1. Data Warehouse Population

Migrate schemas from operational databases to a data warehouse with standardized naming:

```
OLTP: SalesDB.dbo.Orders     →  DW: dw__salesdb__dbo.orders
OLTP: InventoryDB.dbo.Items  →  DW: dw__inventorydb__dbo.items
```

### 2. Database Consolidation

Merge multiple databases into one with schema separation:

```
App1.public.users  →  Consolidated.app1.users
App2.public.users  →  Consolidated.app2.users
```

### 3. Development Environment Setup

Quickly replicate production schema for development:

```bash
# Generate models from production
SOURCE_PG_HOST=prod.example.com ./scripts/01-generate-models.sh

# Apply to local dev database
TARGET_PG_HOST=localhost ./scripts/04-apply-migration.sh
```

### 4. Schema Standardization

Enforce naming conventions across legacy databases:

```
Legacy: tblUSER_DATA  →  Standard: user_data
Legacy: PK_tblUSER    →  Standard: pk_user_data
```

### 5. Multi-Tenant Migrations

Deploy schema changes across multiple tenant databases:

```bash
for tenant in tenant1 tenant2 tenant3; do
    TARGET_PG_DATABASE=$tenant ./scripts/migrate-all.sh
done
```

### 6. Disaster Recovery Preparation

Maintain migration scripts that can recreate schema from scratch:

```bash
# Full schema recreation
alembic downgrade base
alembic upgrade head
```

---

## Conclusion

Code generation for schema migration provides a powerful, automated, and maintainable approach to database schema management. By leveraging sqlacodegen and Alembic, you get:

- **Accuracy**: Machine-generated models match the source exactly
- **Flexibility**: Python transformations enable any naming convention
- **Traceability**: Version-controlled migrations with full history
- **Safety**: Review DDL before applying, rollback if needed
- **Automation**: Scriptable for CI/CD pipelines

This approach is particularly valuable for:
- Data warehouse projects with naming standards
- Legacy database modernization
- Multi-database synchronization
- DevOps-driven database management

For questions or contributions, see the main [README](../README.md).
