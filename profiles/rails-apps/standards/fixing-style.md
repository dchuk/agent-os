---
name: fixing-style
description: Automatically fixes Ruby and Rails code style using RuboCop, maintains consistency with Omakase conventions, and formats code without changing logic
---

# Style Fixing Skill

Automatically fixes Ruby and Rails code style and formatting issues using RuboCop. Maintains consistency with Rails Omakase conventions without modifying business logic.

## Quick Start

Fix style issues in code:
1. Analyze: `bundle exec rubocop [file_or_directory]`
2. Auto-fix: `bundle exec rubocop -a [file_or_directory]`
3. Verify: `bundle exec rubocop [file_or_directory]`
4. Run tests: `bundle exec rspec` or `bin/rails test`

## Core Principles

### 1. Style Only, Never Logic

```ruby
# ✅ CAN FIX: Formatting and spacing
def create
  @user=User.new(user_params)  # Bad spacing
  if @user.save
    redirect_to @user
  end
end

# After fixing:
def create
  @user = User.new(user_params)  # Fixed spacing
  if @user.save
    redirect_to @user
  end
end

# ❌ CANNOT FIX: Business logic changes
# Even if RuboCop suggests it, ASK FIRST before changing:
users = []
User.all.each { |u| users << u.name }
# TO:
users = User.all.map(&:name)  # Changes behavior!
```

### 2. Safe Auto-Correct Only

Use `-a` (safe), not `-A` (aggressive):

```bash
# ✅ SAFE: Only applies safe corrections
bundle exec rubocop -a

# ❌ RISKY: May change logic - ask first
bundle exec rubocop -A
```

### 3. Test After Every Fix

```bash
# Always verify tests still pass
bundle exec rubocop -a app/models/user.rb
bundle exec rspec spec/models/user_spec.rb
```

### 4. Explain What Was Fixed

After fixing, report:
- Which files were modified
- Types of corrections applied
- Any offenses that require manual intervention

## What You CAN Fix

### Formatting and Indentation

```ruby
# BEFORE
class User<ApplicationRecord
def full_name
"#{first_name} #{last_name}"
end
end

# AFTER (fixed by you)
class User < ApplicationRecord
  def full_name
    "#{first_name} #{last_name}"
  end
end
```

### Spaces and Blank Lines

```ruby
# BEFORE
def create
  @user=User.new(user_params)


  if @user.save
    redirect_to @user
  else
    render :new,status: :unprocessable_entity
  end
end

# AFTER (fixed by you)
def create
  @user = User.new(user_params)

  if @user.save
    redirect_to @user
  else
    render :new, status: :unprocessable_entity
  end
end
```

### Naming Conventions

```ruby
# BEFORE
def GetUserData
  userID = params[:id]
  User.find(userID)
end

# AFTER (fixed by you)
def get_user_data
  user_id = params[:id]
  User.find(user_id)
end
```

### Quotes and Interpolation

```ruby
# BEFORE
name = 'John'
message = "Hello " + name

# AFTER (fixed by you)
name = "John"
message = "Hello #{name}"
```

### Modern Hash Syntax

```ruby
# BEFORE
{ :name => "John", :age => 30 }

# AFTER (fixed by you)
{ name: "John", age: 30 }
```

### Method Order in Models

```ruby
# BEFORE
class User < ApplicationRecord
  def full_name
    "#{first_name} #{last_name}"
  end

  validates :email, presence: true
  has_many :items
end

# AFTER (fixed by you)
class User < ApplicationRecord
  # Associations
  has_many :items

  # Validations
  validates :email, presence: true

  # Instance methods
  def full_name
    "#{first_name} #{last_name}"
  end
end
```

### Documentation and Comments

```ruby
# BEFORE
# TODO fix this

# AFTER (fixed by you)
# TODO: Fix this method to handle edge cases
```

## What You CANNOT Fix

### Business Logic

```ruby
# DON'T CHANGE even if RuboCop suggests:
if user.active? && user.premium?
  # Complex logic must be discussed with the team
  grant_access
end
```

### Algorithms

```ruby
# DON'T TRANSFORM automatically:
users = []
User.all.each { |u| users << u.name }

# TO:
users = User.all.map(&:name)
# Even if more idiomatic, this changes behavior
```

### Database Queries

```ruby
# DON'T CHANGE:
User.where(active: true).select(:id, :name)
# TO:
User.where(active: true).pluck(:id, :name)
# This changes the return type
```

### Sensitive Files Without Asking

Ask before touching:
- `config/routes.rb` - Impacts routing
- `db/schema.rb` - Auto-generated
- `config/environments/*.rb` - Critical configuration
- `config/initializers/*.rb` - Application setup

## Commands

### Analysis and Auto-Correction

```bash
# Fix entire project
bundle exec rubocop -a

# Fix specific file
bundle exec rubocop -a app/models/user.rb

# Fix specific directory
bundle exec rubocop -a app/services/

# Fix tests only
bundle exec rubocop -a spec/
```

### Analysis Without Modification

```bash
# Analyze all
bundle exec rubocop

# Detailed format
bundle exec rubocop --format detailed

# Show violated rules
bundle exec rubocop --format offenses

# Specific file
bundle exec rubocop app/models/user.rb
```

### Rule Management

```bash
# Generate TODO list (ask before using!)
bundle exec rubocop --auto-gen-config

# List active cops
bundle exec rubocop --show-cops

# Show config
bundle exec rubocop --show-config
```

## Workflow

### Step 1: Analyze Before Fixing

```bash
bundle exec rubocop app/models/user.rb
```

Examine reported offenses and identify safe auto-corrections.

### Step 2: Apply Safe Auto-Corrections

```bash
bundle exec rubocop -a app/models/user.rb
```

### Step 3: Verify Results

```bash
bundle exec rubocop app/models/user.rb
```

Confirm no offenses remain or list those requiring manual intervention.

### Step 4: Run Tests

```bash
bundle exec rspec spec/models/user_spec.rb
# or
bin/rails test test/models/user_test.rb
```

If tests fail, immediately revert with `git restore` and report the issue.

### Step 5: Document Corrections

Report to user:
```
Fixed style issues in app/models/user.rb:

Applied corrections:
- Indentation (2 spaces)
- Spacing around operators
- Method ordering (associations → validations → methods)
- Modernized hash syntax

Remaining offenses requiring manual intervention:
- Style/ClassLength: User model exceeds 100 lines
- Metrics/CyclomaticComplexity: calculate method is too complex

All tests passing ✓
```

## RuboCop Omakase Standards

This project uses `rubocop-rails-omakase` - official Rails conventions.

### General Principles

1. **Indentation:** 2 spaces (never tabs)
2. **Line length:** Maximum 120 characters
3. **Quotes:** Double quotes by default `"string"`
4. **Hash:** Modern syntax `key: value`
5. **Parentheses:** Required for methods with arguments

### Rails Code Organization

**Models (standard order):**
```ruby
class User < ApplicationRecord
  # Includes and extensions
  include Searchable

  # Constants
  ROLES = %w[admin user guest].freeze

  # Enums
  enum :status, { active: 0, inactive: 1 }

  # Associations
  belongs_to :organization
  has_many :items

  # Validations
  validates :email, presence: true
  validates :name, length: { minimum: 2 }

  # Callbacks
  before_save :normalize_email

  # Scopes
  scope :active, -> { where(status: :active) }

  # Class methods
  def self.find_by_email(email)
    # ...
  end

  # Instance methods
  def full_name
    # ...
  end

  private

  # Private methods
  def normalize_email
    # ...
  end
end
```

**Controllers:**
```ruby
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: %i[show edit update destroy]

  def index
    @users = User.all
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end
end
```

## Typical Use Cases

### Case 1: Lint a New File

```bash
# Format a freshly created file
bundle exec rubocop -a app/services/new_service.rb
```

### Case 2: Clean Specs After Modifications

```bash
# Format all tests
bundle exec rubocop -a spec/
```

### Case 3: Prepare a Commit

```bash
# Check entire project
bundle exec rubocop

# Auto-fix simple issues
bundle exec rubocop -a
```

### Case 4: Lint Specific Directory

```bash
# Format all models
bundle exec rubocop -a app/models/

# Format all controllers
bundle exec rubocop -a app/controllers/
```

## Exception Handling

### When to Disable RuboCop

Sometimes a rule must be ignored for a good reason:

```ruby
# rubocop:disable Style/GuardClause
def complex_method
  if condition
    # Complex code where a guard clause doesn't improve readability
  end
end
# rubocop:enable Style/GuardClause
```

**NEVER add a `rubocop:disable` directive without user approval.**

### Report Uncorrectable Issues

If RuboCop reports offenses you cannot auto-correct:

```
I formatted the code with `bundle exec rubocop -a`, but 3 offenses remain that require manual intervention:

- Style/ClassLength: The DataProcessingService class exceeds 100 lines (refactoring recommended)
- Metrics/CyclomaticComplexity: The calculate method is too complex (simplification needed)
- Metrics/MethodLength: The process method is too long (consider extracting helper methods)

These corrections touch business logic and are outside my scope.
```

## Commands to NEVER Use

❌ **Without Permission:**

```bash
# Generates TODO file that disables all offenses
bundle exec rubocop --auto-gen-config

# Applies potentially dangerous corrections
bundle exec rubocop -A

# Modifies project linting policy
# Manual edits to .rubocop.yml
```

## Boundaries

### Always Do
- Fix formatting and indentation
- Apply naming conventions
- Organize code per Rails standards
- Clean up extra spaces and blank lines
- Run tests after each correction
- Report what was fixed

### Ask First
- Using `rubocop -A` (aggressive mode)
- Disabling cops with `rubocop:disable`
- Modifying `.rubocop.yml` configuration
- Touching sensitive configuration files
- Changes that might affect logic

### Never Do
- Modify business logic
- Change algorithms or data structures
- Refactor without explicit permission
- Touch critical config files without asking
- Skip running tests after fixes
- Dismiss offenses without explanation

## Remember

Your goal: Clean, consistent, standards-compliant code without breaking existing logic. Format and organize, never refactor. When in doubt, ask first. Always test after fixing.
