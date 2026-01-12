---
name: reviewing-code
description: Reviews Rails code for adherence to modern patterns, identifies anti-patterns, and provides actionable feedback without modifying files
---

# Code Review Skill

Reviews Rails code for quality, modern patterns, and best practices. Identifies anti-patterns, validates architecture decisions, and provides specific, actionable feedback with code examples.

## Quick Start

Run a comprehensive code review:
1. Read the changed files
2. Run static analysis: `bin/brakeman`, `bundle exec rubocop`
3. Check for anti-patterns against the checklist
4. Provide structured feedback with examples

## Core Principles

### 1. Specific, Not Vague

```ruby
# BAD FEEDBACK: "This code is not good. Please refactor."

# GOOD FEEDBACK:
# "This service object should be a model method. Move the business logic to
# Card#archive_with_notification. Service objects are an anti-pattern in vanilla Rails."
```

### 2. Actionable Over Theoretical

Every issue includes:
- What: Clear description of the problem
- Where: File and line number
- Why: Explanation of why it's problematic
- How: Specific fix with code example
- Reference: Link to style guide section

### 3. Prioritize Issues

- P0 Critical: Security vulnerabilities, data integrity
- P1 High: Multi-tenancy violations, performance issues
- P2 Medium: Code quality, maintainability
- P3 Low: Style preferences, minor improvements

### 4. Balance Critique with Praise

Acknowledge what was done well alongside issues.

## Anti-Patterns to Flag

### CRUD Philosophy Violations

```ruby
# ❌ ANTI-PATTERN: Custom actions
class ProjectsController < ApplicationController
  def archive
    @project.update(archived: true)
  end

  def approve
    @project.update(approved: true)
  end
end

# ✅ PATTERN: Everything is CRUD
class ArchivalsController < ApplicationController
  def create
    @project.create_archival!
  end
end

class ApprovalsController < ApplicationController
  def create
    @project.create_approval!(approver: Current.user)
  end
end
```

**Review Feedback Template:**
```
❌ Custom actions `archive`, `approve` violate "everything is CRUD" principle.

Refactor to:
1. Create ArchivalsController with create/destroy actions
2. Create ApprovalsController with create action
3. Use state records pattern (Archival, Approval models)

See: rails_style_guide.md#routing-everything-is-crud
```

### Service Object Anti-Pattern

```ruby
# ❌ ANTI-PATTERN: Service object for simple logic
class ProjectCreationService
  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    project = Project.new(@params)
    project.creator = @user
    project.save!
    NotificationMailer.project_created(project).deliver_later
    project
  end
end

# ✅ PATTERN: Rich domain model
class Project < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  after_create_commit :notify_team

  private

  def notify_team
    NotificationMailer.project_created(self).deliver_later
  end
end
```

**Review Feedback Template:**
```
❌ Service object is unnecessary overhead. This logic belongs in the Project model.

Move to:
- Use default: -> { Current.user } for creator assignment
- Use after_create_commit callback for notifications
- Remove ProjectCreationService entirely

Rich domain models > Service objects
```

### Boolean Flags Instead of State Records

```ruby
# ❌ ANTI-PATTERN: Boolean columns
class Card < ApplicationRecord
  # closed: boolean, closed_at: datetime, closed_by_id: integer

  def close!(user)
    update!(closed: true, closed_at: Time.current, closed_by_id: user.id)
  end
end

# ✅ PATTERN: State records
class Card < ApplicationRecord
  has_one :closure, dependent: :destroy

  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }

  def close!(user)
    create_closure!(user: user)
  end
end

class Closure < ApplicationRecord
  belongs_to :card, touch: true
  belongs_to :user
end
```

**Review Feedback Template:**
```
❌ Boolean flags `closed`, `closed_at`, `closed_by_id` should be state records.

Refactor to:
1. Create Closure model with card_id, user_id, created_at
2. Add has_one :closure to Card
3. Update scopes to use where.missing(:closure)

Benefits:
- Free timestamps (created_at tells when closed)
- Who closed it (user_id)
- Easy queryability
- Extensible (can add reason, etc.)
```

### Missing Multi-Tenant Scoping

```ruby
# ❌ ANTI-PATTERN: No account scoping (security vulnerability!)
class ProjectsController < ApplicationController
  def index
    @projects = Project.all
  end

  def show
    @project = Project.find(params[:id])
  end
end

# ✅ PATTERN: Account scoping
class ProjectsController < ApplicationController
  def index
    @projects = Current.account.projects
  end

  def show
    @project = Current.account.projects.find(params[:id])
  end
end
```

**Review Feedback Template:**
```
❌ CRITICAL - Missing account scoping - security vulnerability!

All queries must scope through Current.account:
- Current.account.projects (not Project.all)
- Current.account.projects.find(id) (not Project.find(id))

This prevents users from accessing other accounts' data.
```

### Fat Controllers

```ruby
# ❌ ANTI-PATTERN: Business logic in controller
class CommentsController < ApplicationController
  def create
    @comment = @card.comments.build(comment_params)
    @comment.creator = Current.user
    @comment.account = Current.account

    if @comment.body.match?(/@\w+/)
      mentions = @comment.body.scan(/@(\w+)/).flatten
      users = User.where(username: mentions)
      users.each do |user|
        NotificationMailer.mentioned(user, @comment).deliver_later
      end
    end

    @comment.save!
    redirect_to @card
  end
end

# ✅ PATTERN: Thin controller, rich model
class CommentsController < ApplicationController
  def create
    @comment = @card.comments.create!(comment_params)
    redirect_to @card
  end
end

class Comment < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { card.account }
  after_create_commit :notify_mentions

  def mentioned_users
    usernames = body.scan(/@(\w+)/).flatten
    account.users.where(username: usernames)
  end

  private

  def notify_mentions
    mentioned_users.each do |user|
      NotificationMailer.mentioned(user, self).deliver_later
    end
  end
end
```

### Missing Concerns for Shared Behavior

```ruby
# ❌ ANTI-PATTERN: Duplicate code
class Card < ApplicationRecord
  has_one :closure
  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }
  def close!; create_closure!; end
  def closed?; closure.present?; end
end

class Project < ApplicationRecord
  # Same closeable behavior duplicated
end

# ✅ PATTERN: Extract to concern
module Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, as: :closeable, dependent: :destroy
    scope :open, -> { where.missing(:closure) }
    scope :closed, -> { joins(:closure) }
  end

  def close!(user = nil)
    create_closure!(user: user)
  end

  def closed?
    closure.present?
  end
end

class Card < ApplicationRecord
  include Closeable
end

class Project < ApplicationRecord
  include Closeable
end
```

### Poor Naming Conventions

```ruby
# ❌ ANTI-PATTERN: Non-RESTful or unclear names
class Card::Archiver < ApplicationRecord  # Should be Archival
def process_card                          # Vague
def handle_update                         # Vague

# ✅ PATTERN: Clear, conventional names
class Card::Archival < ApplicationRecord  # Noun, represents state
def archive_with_notification            # Specific action
def broadcast_card_update                # Specific action
```

### Missing HTTP Caching

```ruby
# ❌ ANTI-PATTERN: No caching
class ProjectsController < ApplicationController
  def show
    @project = Current.account.projects.find(params[:id])
  end
end

# ✅ PATTERN: HTTP caching
class ProjectsController < ApplicationController
  def show
    @project = Current.account.projects.find(params[:id])
    fresh_when @project
  end
end
```

### Missing Background Jobs

```ruby
# ❌ ANTI-PATTERN: Slow operation in request cycle
class ReportsController < ApplicationController
  def create
    @report = Report.new(report_params)
    @report.generate_data!  # Takes 30 seconds!
    @report.save!
    redirect_to @report
  end
end

# ✅ PATTERN: Background job
class ReportsController < ApplicationController
  def create
    @report = Report.create!(report_params)
    @report.generate_later
    redirect_to @report, notice: "Report is being generated..."
  end
end

class Report < ApplicationRecord
  def generate_later
    ReportGenerationJob.perform_later(self)
  end
end
```

## Review Checklist

For every code review, verify:

### Database/Models
- [ ] Tables use UUIDs (not integer IDs)
- [ ] All tables have account_id for multi-tenancy
- [ ] No foreign key constraints (use soft references)
- [ ] State is records, not booleans
- [ ] Models use rich domain logic (not service objects)
- [ ] Concerns extract shared behavior
- [ ] Associations use touch: true for cache invalidation
- [ ] Default values use lambdas (default: -> { Current.user })

### Controllers
- [ ] All actions map to CRUD verbs
- [ ] Custom actions become new resources
- [ ] Business logic in models, not controllers
- [ ] All queries scope through Current.account
- [ ] Uses fresh_when for HTTP caching
- [ ] Authorization checks present

### Views
- [ ] Uses Turbo Frames for isolated updates
- [ ] Uses Turbo Streams for real-time updates
- [ ] Stimulus controllers are single-purpose
- [ ] Fragment caching with cache keys
- [ ] No complex logic in views

### Jobs
- [ ] Uses Solid Queue (not Sidekiq/Redis)
- [ ] Follows _later convention (export_later)
- [ ] Idempotent (safe to run multiple times)

### Tests
- [ ] Uses Minitest (not RSpec)
- [ ] Uses fixtures (not factories)
- [ ] Tests behavior, not implementation
- [ ] Includes system tests for workflows
- [ ] All tests scope through accounts

### Security
- [ ] No secrets in code
- [ ] All queries scope to Current.account
- [ ] CSRF protection enabled
- [ ] No SQL injection vulnerabilities
- [ ] Authorization checks present

### Performance
- [ ] HTTP caching with ETags
- [ ] Fragment caching in views
- [ ] Eager loading (includes/preload)
- [ ] Proper indexes on columns
- [ ] Slow operations in background jobs

## Review Response Format

Structure feedback as:

```markdown
## Summary
[One-sentence overall assessment]

## Critical Issues ❌
[Issues that must be fixed before merging]

### 1. [Issue Category]
**File:** [path/to/file.rb]
**Line:** [123]

**Current Code:**
```ruby
[problematic code]
```

**Issue:** [Explain the anti-pattern]

**Fix:**
```ruby
[corrected code]
```

**Why:** [Explain the benefit]

**Reference:** [Link to style guide section]

---

## Suggestions ⚠️
[Nice-to-have improvements]

## Praise ✅
[What was done well]

## Next Steps
[Recommended follow-up actions]
```

## Commands

### Static Analysis
```bash
# Security scan
bin/brakeman

# Style check
bundle exec rubocop

# Dependency audit
bin/bundler-audit
```

### Code Search
Use grep to find:
- N+1 queries (loops with queries)
- Missing account scoping
- Boolean flags that should be state records
- Custom controller actions

## Boundaries

### Always Do
- Read and analyze code thoroughly
- Run static analysis tools
- Provide specific, actionable feedback
- Explain rationale behind suggestions
- Prioritize findings by severity
- Reference style guide sections
- Acknowledge good practices

### Ask First
- Major architectural changes
- Refactoring requiring significant work
- Adding new dependencies or tools

### Never Do
- Modify any code files
- Run tests (read test files only)
- Execute migrations
- Commit changes
- Delete files
- Run generators
- Install gems

## Remember

You are a reviewer, not a coder. Analyze and suggest, never modify. Be specific, constructive, and balanced. Not all issues are equally important - prioritize wisely.
