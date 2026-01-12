---
name: building-models
description: Builds rich domain models with proper associations, validations, scopes, and business logic using a hybrid approach that balances fat models with selective service extraction
---

# Building Models

Builds rich domain models that encapsulate business behavior while maintaining clarity. Follows a hybrid philosophy: simple domain logic lives in models, complex multi-step workflows can be delegated to services when needed.

## Quick Start

**Generate a model:**
```bash
bin/rails generate model Card title:string body:text account:references:uuid
bin/rails db:migrate
```

**Basic model structure:**
```ruby
class Card < ApplicationRecord
  # Concerns
  include Closeable, Assignable, Searchable

  # Associations
  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  # Validations
  validates :title, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { open.published.where.missing(:not_now) }

  # Business logic
  def publish
    update!(status: :published)
    track_event "card_published"
  end
end
```

## Core Principles

### 1. Rich Models Over Anemic Data Containers

Models should contain behavior, not just data. Business logic belongs in models when it's focused on a single model's domain.

**Prefer:**
```ruby
class Card < ApplicationRecord
  def close(user: Current.user)
    create_closure!(user: user)
    track_event "card_closed", user: user
    notify_watchers_later
  end
end

# Controller
@card.close
```

**Over:**
```ruby
# Service object for simple operations
class CloseCardService
  def call
    @card.create_closure!(user: @user)
    @card.track_event("card_closed", user: @user)
    NotifyWatchersJob.perform_later(@card)
  end
end
```

### 2. Hybrid Approach: Models + Selective Services

- **Simple logic in models:** State changes, validations, simple calculations
- **Complex logic in services:** Multi-model operations, external API calls, complex workflows
- **Concerns for organization:** Horizontal behavior sharing across models

### 3. Use Concerns to Organize Behavior

Compose rich models from focused concerns rather than creating god objects.

```ruby
class Card < ApplicationRecord
  include Assignable, Closeable, Colored, Commentable,
          Eventable, Golden, Positionable, Searchable, Watchable

  # Model-specific code remains minimal
  belongs_to :board
  validates :title, presence: true
end
```

### 4. Default Values via Lambdas

Set defaults intelligently using lambdas that access related records.

```ruby
belongs_to :account, default: -> { board.account }
belongs_to :creator, class_name: "User", default: -> { Current.user }
```

### 5. Keep Models Testable

Write tests for validations, associations, scopes, and business logic.

```ruby
# test/models/card_test.rb
test "closing card creates closure record" do
  assert_difference -> { Closure.count }, 1 do
    @card.close
  end

  assert @card.closed?
  assert_equal @user, @card.closed_by
end
```

## Patterns

### Association Patterns

**belongs_to with defaults:**
```ruby
belongs_to :account, default: -> { board.account }
belongs_to :creator, class_name: "User", default: -> { Current.user }
belongs_to :board, touch: true  # Updates parent's updated_at
```

**has_many/has_one patterns:**
```ruby
has_many :comments, dependent: :destroy
has_many :assignments, dependent: :destroy
has_many :assignees, through: :assignments, source: :user

has_one :closure, dependent: :destroy
has_one :publication, dependent: :destroy
```

**Polymorphic associations:**
```ruby
has_many :attachments, as: :attachable, dependent: :destroy
has_many :events, as: :eventable, dependent: :destroy
belongs_to :notifiable, polymorphic: true
```

**Counter caches:**
```ruby
belongs_to :card, counter_cache: :comments_count
belongs_to :board, counter_cache: :cards_count
```

### Scope Patterns

**Basic scopes:**
```ruby
scope :recent, -> { order(created_at: :desc) }
scope :positioned, -> { order(:position) }
scope :active, -> { where(archived_at: nil) }
```

**Scopes with arguments:**
```ruby
scope :by_creator, ->(user) { where(creator: user) }
scope :in_column, ->(column) { where(column: column) }
scope :created_after, ->(date) { where("created_at > ?", date) }
```

**Scopes using joins:**
```ruby
scope :assigned_to, ->(user) { joins(:assignments).where(assignments: { user: user }) }
scope :watched_by, ->(user) { joins(:watches).where(watches: { user: user }) }
```

**Scopes using where.missing:**
```ruby
scope :open, -> { where.missing(:closure) }
scope :unassigned, -> { where.missing(:assignments) }
scope :active, -> { where.missing(:not_now) }
```

**Complex scopes:**
```ruby
scope :with_golden_first, -> {
  left_outer_joins(:goldness)
    .select("cards.*", "goldnesses.created_at as golden_at")
    .order(Arel.sql("golden_at IS NULL, golden_at DESC"))
}

scope :entropic, -> {
  open.published.where.missing(:not_now).where("updated_at < ?", 30.days.ago)
}
```

### Validation Patterns

**Simple validations:**
```ruby
validates :title, presence: true
validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
validates :status, inclusion: { in: %w[draft published archived] }
validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
```

**Uniqueness validations:**
```ruby
validates :email_address, uniqueness: { case_sensitive: false }
validates :user_id, uniqueness: { scope: :card_id }
validates :card, uniqueness: true  # For has_one relationships
```

**Custom validations:**
```ruby
validate :ensure_same_account

private

def ensure_same_account
  if board && board.account_id != account_id
    errors.add(:board, "must belong to the same account")
  end
end
```

### Callback Patterns

Use callbacks sparingly. Prefer explicit methods over hidden side effects.

**Good uses:**
```ruby
# Broadcasting and tracking
after_create_commit :broadcast_creation
after_create_commit :track_created_event

# Setting defaults
before_validation :set_default_status, on: :create
```

**Use with caution:**
```ruby
# Side effects - consider explicit method calls instead
after_create_commit :notify_recipients
```

**Callback timing:**
```ruby
before_validation :normalize_email
after_create_commit :send_notifications  # For external side effects
after_update_commit :broadcast_update
after_destroy_commit :cleanup_related_records
```

### Enum Patterns

```ruby
# String enums (preferred for database readability)
enum :status, {
  draft: "draft",
  published: "published",
  archived: "archived"
}, default: :draft, prefix: true

# Usage:
card.status_draft!
card.status_published?
Card.status_published
```

### Delegation Patterns

```ruby
# Delegate to associations
delegate :name, to: :board, prefix: true  # board_name
delegate :email, to: :creator, prefix: :author  # author_email
delegate :can_administer_card?, to: :board, prefix: false

# With allow_nil
delegate :name, to: :board, prefix: true, allow_nil: true
```

### Business Logic Methods

**Action methods (verbs):**
```ruby
def close(user: Current.user)
  create_closure!(user: user)
  track_event "card_closed", user: user
  notify_watchers_later
end

def assign(user)
  assignments.create!(user: user) unless assigned_to?(user)
  track_event "card_assigned", particulars: { assignee_id: user.id }
end
```

**Query methods (predicates):**
```ruby
def closed?
  closure.present?
end

def assigned_to?(user)
  assignees.include?(user)
end

def can_be_edited_by?(user)
  user.can_administer_card?(self) || creator == user
end
```

**Computed attributes:**
```ruby
def closed_at
  closure&.created_at
end

def closed_by
  closure&.user
end
```

### _later and _now Convention

```ruby
# Async version (queues a job)
def notify_recipients_later
  NotifyRecipientsJob.perform_later(self)
end

# Sync version (immediate execution)
def notify_recipients_now
  recipients.each do |recipient|
    Notification.create!(recipient: recipient, notifiable: self)
  end
end

# Default to sync, call _later from callbacks
def notify_recipients
  notify_recipients_now
end

after_create_commit :notify_recipients_later
```

### Using Current for Context

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :identity, :account
end

# In models, use Current for request context
class Card < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { Current.account }

  def close(user: Current.user)
    create_closure!(user: user)
  end
end
```

## Commands

### Tests
```bash
# All model tests
bin/rails test test/models/

# Specific model
bin/rails test test/models/card_test.rb

# With RSpec
bundle exec rspec spec/models/
bundle exec rspec spec/models/card_spec.rb
```

### Database
```bash
# Generate model
bin/rails generate model Card title:string body:text account:references:uuid

# Generate migration
bin/rails generate migration AddColorToCards color:string

# Run migrations
bin/rails db:migrate

# Check schema
bin/rails db:schema:dump

# Console
bin/rails console
```

### Linting
```bash
# Lint models
bundle exec rubocop -a app/models/

# Validate factories (if using FactoryBot)
bundle exec rake factory_bot:lint
```

## Boundaries

### ✅ Always Do

- Put business logic in models when it's focused on single-model domain concerns
- Use concerns to organize horizontal behavior across models
- Include tests for all business logic (associations, validations, scopes, methods)
- Use bang methods (`create!`, `update!`) in models to catch errors
- Leverage associations and scopes for clean queries
- Use `Current` for request context (user, account, session)
- Set default values via lambdas when they depend on other attributes
- Include `account_id` on multi-tenant models
- Touch parent records when appropriate (`touch: true`)
- Validate data integrity at the model level

### ⚠️ Ask First

- Before creating service objects (is this truly complex multi-model logic?)
- Before adding complex callbacks (can this be an explicit method call?)
- Before using inheritance (can concerns provide the behavior instead?)
- Before creating form objects (are they truly needed?)
- Before major schema changes or removing existing associations

### 🚫 Never Do

- Create anemic models (just data, no behavior)
- Put business logic in controllers
- Skip validations or tests
- Use magic numbers (use constants or enums)
- Create models without tests
- Forget `account_id` on multi-tenant models
- Use foreign key constraints (explicitly removed in this architecture)
- Add callbacks for complex multi-step workflows (use explicit methods or services)
- Query extensively across models in callbacks (can cause performance issues)

## When NOT to Use Models

**Avoid models for:**
- One-off scripts (use rake tasks)
- Complex multi-step workflows spanning many models (use service objects)
- Pure view logic (use helpers or POROs in `app/models/[model]/`)

**Exception:** Form objects for signup/onboarding

```ruby
# app/models/signup.rb
class Signup
  include ActiveModel::Model

  attr_accessor :email_address, :full_name, :password

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, presence: true

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      create_identity
      create_user
      create_account
    end
  end

  private

  def create_identity
    @identity = Identity.create!(email_address: email_address)
  end
end
```

## Remember

- **Rich, not anemic:** Models should have behavior, not just data
- **Hybrid approach:** Simple logic in models, complex workflows in services
- **Organize with concerns:** Compose behavior from focused modules
- **Test thoroughly:** Every validation, association, scope, and business method
- **Use Current wisely:** For request-scoped context like current user/account
- **Scopes for queries:** Build composable, reusable query logic
- **Explicit over implicit:** Prefer named methods over hidden callbacks
