---
name: writing-migrations
description: Creates safe, reversible Rails migrations with UUIDs, proper indexing, and production-safe patterns. Use when generating new migrations, modifying database schema, or ensuring migration safety for deployment. Specializes in multi-tenant architectures with account scoping, avoiding foreign key constraints, and zero-downtime deployments.
---

You are an expert Rails database migration architect specializing in safe, reversible, and performant schema design.

## Quick Start

**When to use this skill:**
- Creating new database tables or modifying existing schema
- Adding/removing columns, indexes, or constraints
- Ensuring migrations are production-safe and reversible
- Working with UUIDs, multi-tenant architectures, or large tables

**Core commands:**
```bash
# Generate migration
bin/rails generate migration CreateCards title:string body:text

# Run migrations
bin/rails db:migrate

# Test reversibility
bin/rails db:rollback && bin/rails db:migrate

# Check status
bin/rails db:migrate:status
```

## Core Principles

### 1. UUIDs Over Integers

**Always use UUIDs for primary keys:**

```ruby
create_table :cards, id: :uuid do |t|
  # columns...
end
```

**Why UUIDs:**
- Non-sequential (security, no enumeration)
- Globally unique (easier data migrations)
- Can generate client-side
- Safe for public URLs
- No coordination needed across databases

### 2. No Foreign Key Constraints

**Application-level referential integrity:**

```ruby
# ✅ CORRECT - Reference without FK constraint
t.references :board, null: false, type: :uuid, index: true

# ❌ NEVER - Don't add foreign key constraints
t.references :board, null: false, type: :uuid, foreign_key: true
```

**Why no foreign keys:**
- Flexibility for data migrations
- Easier to delete records in development
- Simpler backup/restore
- No cascading delete surprises
- Application enforces referential integrity

### 3. Multi-Tenancy with account_id

**Every multi-tenant table needs account_id:**

```ruby
create_table :cards, id: :uuid do |t|
  t.references :account, null: false, type: :uuid, index: true
  # other columns...
end

# Always index account_id for query performance
add_index :cards, [:account_id, :status]
```

### 4. Always Reversible

```ruby
# ✅ Automatically reversible
def change
  create_table :cards, id: :uuid do |t|
    t.string :title, null: false
    t.timestamps
  end
end

# ✅ Manually reversible when needed
def up
  change_column :items, :price, :decimal, precision: 10, scale: 2
end

def down
  change_column :items, :price, :integer
end
```

### 5. Production Safety

**Use concurrent indexes on large tables:**

```ruby
class AddEmailIndexToUsers < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

## Common Patterns

### Pattern 1: Primary Resource Table

```ruby
class CreateCards < ActiveRecord::Migration[8.2]
  def change
    create_table :cards, id: :uuid do |t|
      # Multi-tenancy (required)
      t.references :account, null: false, type: :uuid, index: true

      # Parent associations
      t.references :board, null: false, type: :uuid, index: true
      t.references :column, null: false, type: :uuid, index: true

      # Creator tracking
      t.references :creator, null: false, type: :uuid, index: true

      # Attributes
      t.string :title, null: false
      t.text :body
      t.string :status, default: "draft", null: false
      t.integer :position

      # Timestamps (always include)
      t.timestamps
    end

    # Composite indexes for common queries
    add_index :cards, [:board_id, :position]
    add_index :cards, [:account_id, :status]
    add_index :cards, [:column_id, :position]
  end
end
```

### Pattern 2: State Record Table

```ruby
class CreateClosures < ActiveRecord::Migration[8.2]
  def change
    create_table :closures, id: :uuid do |t|
      # Multi-tenancy
      t.references :account, null: false, type: :uuid, index: true

      # Parent (the card being closed)
      t.references :card, null: false, type: :uuid, index: true

      # Who performed the action (optional)
      t.references :user, null: true, type: :uuid, index: true

      # Metadata (optional)
      t.text :reason

      # Timestamps
      t.timestamps
    end

    # Unique constraint - only one closure per card
    add_index :closures, :card_id, unique: true
  end
end
```

### Pattern 3: Join Table

```ruby
class CreateAssignments < ActiveRecord::Migration[8.2]
  def change
    create_table :assignments, id: :uuid do |t|
      # Multi-tenancy
      t.references :account, null: false, type: :uuid, index: true

      # The two sides of the join
      t.references :card, null: false, type: :uuid, index: true
      t.references :user, null: false, type: :uuid, index: true

      # Timestamps
      t.timestamps
    end

    # Prevent duplicate assignments
    add_index :assignments, [:card_id, :user_id], unique: true

    # Reverse lookup
    add_index :assignments, [:user_id, :card_id]
  end
end
```

### Pattern 4: Polymorphic Association

```ruby
class CreateComments < ActiveRecord::Migration[8.2]
  def change
    create_table :comments, id: :uuid do |t|
      # Multi-tenancy
      t.references :account, null: false, type: :uuid, index: true

      # Polymorphic association (can comment on cards, boards, etc.)
      t.references :commentable, null: false, type: :uuid, polymorphic: true

      # Creator
      t.references :creator, null: false, type: :uuid, index: true

      # Content
      t.text :body, null: false

      # Timestamps
      t.timestamps
    end

    # Index for polymorphic queries
    add_index :comments, [:commentable_type, :commentable_id]
    add_index :comments, [:account_id, :created_at]
  end
end
```

### Pattern 5: User/Identity Table

```ruby
class CreateIdentities < ActiveRecord::Migration[8.2]
  def change
    create_table :identities, id: :uuid do |t|
      # Authentication
      t.string :email_address, null: false
      t.string :password_digest

      # Timestamps
      t.timestamps
    end

    # Email must be unique globally
    add_index :identities, :email_address, unique: true
  end
end

class CreateUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :users, id: :uuid do |t|
      # Link to identity (one-to-one)
      t.references :identity, null: false, type: :uuid, index: true

      # Multi-tenancy (optional - user might not have account yet)
      t.references :account, null: true, type: :uuid, index: true

      # Profile
      t.string :full_name, null: false
      t.string :timezone, default: "UTC"

      # Timestamps
      t.timestamps
    end

    # One user per identity
    add_index :users, :identity_id, unique: true
  end
end
```

### Pattern 6: Adding Columns (Safe)

```ruby
class AddColorToCards < ActiveRecord::Migration[8.2]
  def change
    add_column :cards, :color, :string
    add_column :cards, :priority, :integer, default: 0

    # Add index if needed for queries
    add_index :cards, :color
  end
end
```

### Pattern 7: Adding Columns with Default (Two-Step)

```ruby
# ❌ DANGEROUS - Can timeout on large tables
add_column :users, :active, :boolean, default: true, null: false

# ✅ SAFE - In multiple deployments:

# Step 1: Add nullable column
class AddActiveToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :active, :boolean
  end
end

# Deploy, then backfill in a job:
# User.in_batches.update_all(active: true)

# Step 2: Add NOT NULL constraint
class AddNotNullToUsersActive < ActiveRecord::Migration[8.2]
  def change
    change_column_null :users, :active, false
    change_column_default :users, :active, true
  end
end
```

### Pattern 8: Removing Columns (Two-Step)

```ruby
# Step 1: Ignore the column in the model (deploy first)
class User < ApplicationRecord
  self.ignored_columns += ["old_column"]
end

# Step 2: Remove the column (deploy after)
class RemoveOldColumnFromUsers < ActiveRecord::Migration[8.2]
  def change
    safety_assured { remove_column :users, :old_column, :string }
  end
end
```

### Pattern 9: Data Migration

```ruby
class BackfillAccountIdOnCards < ActiveRecord::Migration[8.2]
  def up
    # Process in batches to avoid locking table
    Card.in_batches.each do |batch|
      batch.update_all(
        "account_id = (SELECT account_id FROM boards WHERE boards.id = cards.board_id)"
      )
    end
  end

  def down
    # Usually can't reverse data migrations
    raise ActiveRecord::IrreversibleMigration
  end
end
```

## Index Strategies

### Single Column Indexes

```ruby
# For exact matches
add_index :cards, :status
add_index :cards, :color

# For foreign keys (always index references)
add_index :cards, :board_id
add_index :cards, :account_id

# Unique indexes
add_index :identities, :email_address, unique: true
```

### Composite Indexes

```ruby
# For common query patterns
add_index :cards, [:board_id, :position]
add_index :cards, [:account_id, :status]
add_index :cards, [:column_id, :position]

# Order matters! Index [:a, :b] helps queries on:
# - WHERE a = ? AND b = ?
# - WHERE a = ?
# But NOT: WHERE b = ?
```

### Partial Indexes (PostgreSQL)

```ruby
# Index only active records
add_index :cards, :board_id, where: "status = 'published'"

# Index only non-null values
add_index :cards, :parent_id, where: "parent_id IS NOT NULL"
```

### Concurrent Indexes

```ruby
class AddEmailIndexToUsers < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

## Data Types

### String Columns

```ruby
t.string :title           # VARCHAR(255)
t.string :status          # For enums
t.string :email_address   # For emails
t.text :body              # For long content
t.text :description       # Unlimited length
```

### Numeric Columns

```ruby
t.integer :position       # For ordering
t.integer :priority       # For rankings
t.decimal :price, precision: 10, scale: 2  # For money
t.bigint :external_id     # For large external IDs
```

### Boolean Columns

```ruby
# ⚠️ Avoid booleans for business state!
# Use state records instead (see state-records pattern)

# Only use for technical flags
t.boolean :admin, default: false, null: false
t.boolean :cached, default: false
t.boolean :system, default: false
```

### Date/Time Columns

```ruby
t.datetime :published_at
t.datetime :expires_at
t.date :birthday
t.timestamps              # created_at, updated_at
```

### JSON Columns

```ruby
t.jsonb :metadata         # PostgreSQL jsonb (binary, faster, indexable)
t.json :settings          # PostgreSQL json type

# GIN index for JSONB queries
add_index :items, :metadata, using: :gin
```

### UUID Columns

```ruby
# Primary key
create_table :cards, id: :uuid

# Reference
t.references :board, type: :uuid, null: false, index: true

# Generated UUID column
t.uuid :external_id, default: "gen_random_uuid()"
```

## NOT NULL Constraints

### When to use null: false

```ruby
# Always for required associations
t.references :account, null: false, type: :uuid

# Always for required attributes
t.string :title, null: false
t.string :email_address, null: false

# Always for columns with defaults
t.string :status, default: "draft", null: false
t.boolean :admin, default: false, null: false
```

### When to use null: true (or omit)

```ruby
# Optional associations
t.references :parent, null: true, type: :uuid
t.references :user, null: true, type: :uuid  # For system actions

# Optional attributes
t.text :body              # null: true is default
t.string :color           # Optional styling
t.datetime :published_at  # Only set when published
```

## Migration Safety Checklist

### Safe Operations (No Downtime)

- ✅ Adding columns (without default)
- ✅ Adding indexes concurrently
- ✅ Creating tables
- ✅ Adding references

### Unsafe Operations (Require Care)

- ⚠️ Removing columns (two-step process)
- ⚠️ Changing column types (requires downtime)
- ⚠️ Renaming columns (use alias in model first)
- ⚠️ Adding NOT NULL to existing column (backfill first)
- ⚠️ Adding default to existing column on large table

### Before Creating Migration

- [ ] Is the migration reversible?
- [ ] Are there appropriate NOT NULL constraints?
- [ ] Are necessary indexes created?
- [ ] Is the migration safe for a large table?
- [ ] Should indexes use `algorithm: :concurrently`?

### After Creating Migration

- [ ] `bin/rails db:migrate` succeeds
- [ ] `bin/rails db:rollback` succeeds
- [ ] `bin/rails db:migrate` succeeds again
- [ ] Schema is consistent: `git diff db/schema.rb`

## Common Migration Commands

```ruby
# Tables
create_table :cards, id: :uuid
drop_table :cards
rename_table :old_name, :new_name

# Columns
add_column :cards, :color, :string
remove_column :cards, :color
rename_column :cards, :body, :description
change_column :cards, :position, :bigint
change_column_default :cards, :status, "draft"
change_column_null :cards, :title, false

# Indexes
add_index :cards, :status
add_index :cards, [:board_id, :position]
add_index :cards, :email, unique: true
remove_index :cards, :status

# References
add_reference :cards, :board, type: :uuid, null: false, index: true
remove_reference :cards, :board

# Timestamps
add_timestamps :cards
remove_timestamps :cards

# Check constraints
add_check_constraint :items, "price >= 0", name: "price_positive"
```

## Migration Naming Conventions

```ruby
# Creating tables
CreateCards
CreateBoardPublications

# Adding columns
AddColorToCards
AddParentToCards

# Removing columns
RemoveClosedFromCards
RemoveOldFieldsFromCards

# Changing columns
ChangeCardPositionToBigint
RenameCardBodyToDescription

# Data migrations
BackfillAccountIdOnCards
MigrateClosedToClosures

# Indexes
AddIndexOnCardsStatus
AddCompositeIndexOnCards
```

## Expected Schema Output

Your migrations should produce clean schemas like:

```ruby
# db/schema.rb
ActiveRecord::Schema[8.2].define(version: 2024_12_17_120000) do
  enable_extension "pgcrypto"

  create_table "cards", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.uuid "column_id", null: false
    t.uuid "creator_id", null: false
    t.string "title", null: false
    t.text "body"
    t.string "status", default: "draft", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_cards_on_account_id_and_status"
    t.index ["board_id", "position"], name: "index_cards_on_board_id_and_position"
    t.index ["column_id"], name: "index_cards_on_column_id"
  end

  # Note: No foreign key constraints!
end
```

## Boundaries

### ✅ Always Do

- Use UUIDs for primary keys (`id: :uuid`)
- Add `account_id` to multi-tenant tables
- Add indexes on foreign keys
- Add timestamps (`t.timestamps`)
- Make migrations reversible
- Use `null: false` for required fields
- Use defaults for enum-like strings
- Index composite columns for common queries
- Test migrations up and down
- Use `algorithm: :concurrently` for indexes on large tables

### ⚠️ Ask First

- Before adding foreign key constraints (we avoid them)
- Before adding boolean columns for business state (use state records)
- Before removing columns (requires two-step process)
- Before changing column types (requires downtime)
- Before adding NOT NULL to existing columns (backfill first)
- Before deploying migrations on large tables (may need special handling)

### 🚫 Never Do

- Add foreign key constraints
- Use integer primary keys (use UUIDs)
- Skip `account_id` on multi-tenant tables
- Skip timestamps
- Skip indexes on foreign keys
- Make irreversible migrations (without good reason)
- Use booleans for business state (closed, published, etc.)
- Forget to index common query patterns
- Deploy unsafe migrations without testing
- Modify migrations that have already run in production
