---
name: extracting-concerns
description: Extracts and organizes model and controller concerns for horizontal code sharing, creating self-contained modules that bundle associations, validations, callbacks, and methods together
---

# Extracting Concerns

Identifies repeated patterns across models or controllers and extracts them into reusable concerns. Creates self-contained, cohesive modules that handle one aspect of behavior.

## Quick Start

**Create a model concern:**
```ruby
# app/models/card/closeable.rb
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy
    scope :open, -> { where.missing(:closure) }
    scope :closed, -> { joins(:closure) }
  end

  def close(user: Current.user)
    create_closure!(user: user)
    track_event "card_closed", user: user
  end

  def closed?
    closure.present?
  end

  def closed_at
    closure&.created_at
  end
end
```

**Include in model:**
```ruby
class Card < ApplicationRecord
  include Closeable
end
```

## Core Principles

### 1. Concerns for Horizontal Behavior

Use concerns when multiple models/controllers need the same behavior:
- **Self-contained:** All related code (associations, validations, scopes, methods) in one place
- **Cohesive:** Focused on one aspect (e.g., `Closeable`, `Watchable`, `Searchable`)
- **Composable:** Models include multiple concerns to build up behavior

### 2. Bundle Related Code Together

A concern should include ALL code related to one capability:
- Associations
- Validations
- Scopes
- Callbacks
- Instance methods
- Class methods

### 3. Name Concerns Descriptively

**Model concerns (adjectives):**
`Closeable`, `Publishable`, `Watchable`, `Assignable`, `Searchable`

**Controller concerns (nouns/descriptive):**
`CardScoped`, `FilterScoped`, `CurrentRequest`

### 4. Namespace Model Concerns

```
app/models/card/closeable.rb
app/models/card/assignable.rb
app/models/board/publishable.rb
```

### 5. Keep Concerns Focused

One concern = one aspect of behavior. Don't create god concerns.

## Patterns

### Model Concern: State Management

```ruby
# app/models/card/closeable.rb
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy
    scope :open, -> { where.missing(:closure) }
    scope :closed, -> { joins(:closure) }
    after_create_commit :track_card_created_event
  end

  def close(user: Current.user)
    create_closure!(user: user)
    track_event "card_closed", user: user
  end

  def reopen
    closure&.destroy!
    track_event "card_reopened"
  end

  def closed?
    closure.present?
  end

  def closed_at
    closure&.created_at
  end

  def closed_by
    closure&.user
  end

  private

  def track_card_created_event
    track_event "card_created" if open?
  end
end
```

### Model Concern: Association Behavior

```ruby
# app/models/card/assignable.rb
module Card::Assignable
  extend ActiveSupport::Concern

  included do
    has_many :assignments, dependent: :destroy
    has_many :assignees, through: :assignments, source: :user
    scope :assigned_to, ->(user) { joins(:assignments).where(assignments: { user: user }) }
    scope :unassigned, -> { where.missing(:assignments) }
  end

  def assign(user)
    assignments.create!(user: user) unless assigned_to?(user)
    track_event "card_assigned", user: user, particulars: { assignee_id: user.id }
  end

  def unassign(user)
    assignments.where(user: user).destroy_all
    track_event "card_unassigned", user: user, particulars: { assignee_id: user.id }
  end

  def assigned_to?(user)
    assignees.include?(user)
  end
end
```

### Model Concern: Search Behavior

```ruby
# app/models/card/searchable.rb
module Card::Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) { where("title LIKE ? OR body LIKE ?", "%#{query}%", "%#{query}%") }
  end

  class_methods do
    def search_with_ranking(query)
      search(query).order("search_rank DESC")
    end

    def top_results(query, limit: 10)
      search_with_ranking(query).limit(limit)
    end
  end
end
```

### Model Concern: Event Tracking

```ruby
# app/models/card/eventable.rb
module Card::Eventable
  include ::Eventable

  PERMITTED_ACTIONS = %w[
    card_created card_closed card_reopened
    card_assigned card_unassigned
  ]

  def track_title_change(old_title)
    track_event "title_changed", particulars: {
      old_title: old_title,
      new_title: title
    }
  end

  def track_body_change
    track_event "body_changed" if saved_change_to_body?
  end
end
```

### Controller Concern: Resource Scoping

```ruby
# app/controllers/concerns/card_scoped.rb
module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_card
    before_action :set_board
  end

  private

  def set_card
    @card = Current.account.cards.find(params[:card_id])
  end

  def set_board
    @board = @card.board
  end

  def render_card_replacement
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@card, :card_container),
          partial: "cards/container",
          locals: { card: @card.reload }
        )
      end
      format.html { redirect_to @card }
    end
  end
end
```

### Controller Concern: Request Context

```ruby
# app/controllers/concerns/current_request.rb
module CurrentRequest
  extend ActiveSupport::Concern

  included do
    before_action :set_current_request_details
  end

  private

  def set_current_request_details
    Current.user = current_user
    Current.identity = current_identity
    Current.session = current_session
    Current.account = current_account
  end
end
```

### Controller Concern: Filtering

```ruby
# app/controllers/concerns/filter_scoped.rb
module FilterScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_filter
    helper_method :filter, :filtered?
  end

  private

  def set_filter
    @filter = if params[:filter_id].present?
      Current.account.filters.find(params[:filter_id])
    else
      Filter.new(filter_params)
    end
  end

  def filter
    @filter
  end

  def filtered?
    @filter.persisted? || filter_params.any?
  end

  def filter_params
    params.fetch(:filter, {}).permit(:assignee_id, :column_id, :tag_id, :closed)
  end
end
```

## When to Extract a Concern

### Extract When You See:

**1. Repeated associations across models:**
```ruby
# Multiple models have:
has_many :comments, as: :commentable
has_many :attachments, as: :attachable

# Extract to:
# app/models/concerns/commentable.rb
# app/models/concerns/attachable.rb
```

**2. Repeated state patterns:**
```ruby
# Multiple models have closure/publication pattern
has_one :closure
def close; end
def reopen; end
def closed?; end

# Extract to Card::Closeable, Board::Publishable, etc.
```

**3. Repeated scopes:**
```ruby
# Multiple models have:
scope :recent, -> { order(created_at: :desc) }
scope :by_creator, ->(user) { where(creator: user) }

# Extract to Timestampable or Ownable concern
```

**4. Repeated controller patterns:**
```ruby
# Multiple controllers have:
before_action :set_parent_resource

# Extract to ParentScoped concern
```

## Concern Composition

Models include multiple concerns to build rich behavior:

```ruby
# app/models/card.rb
class Card < ApplicationRecord
  include Assignable, Attachments, Broadcastable, Closeable,
          Colored, Commentable, Eventable, Golden, Positionable,
          Searchable, Viewable, Watchable

  # Minimal model code - behavior is in concerns
  belongs_to :board
  belongs_to :column
  validates :title, presence: true
end
```

## class_methods Block

For class-level methods:

```ruby
module Card::Searchable
  extend ActiveSupport::Concern

  included do
    scope :search, ->(query) { where("title LIKE ?", "%#{query}%") }
  end

  class_methods do
    def search_with_ranking(query)
      search(query).order("search_rank DESC")
    end

    def top_results(query, limit: 10)
      search_with_ranking(query).limit(limit)
    end
  end
end
```

## Testing Concerns

### Test in Isolation

```ruby
# test/models/concerns/closeable_test.rb
require "test_helper"

class CloseableTest < ActiveSupport::TestCase
  class DummyCloseable < ApplicationRecord
    self.table_name = "cards"
    include Card::Closeable
  end

  setup do
    @record = DummyCloseable.create!(title: "Test")
  end

  test "close creates closure record" do
    assert_difference -> { Closure.count }, 1 do
      @record.close
    end
    assert @record.closed?
  end

  test "reopen destroys closure record" do
    @record.close
    assert_difference -> { Closure.count }, -1 do
      @record.reopen
    end
    assert @record.open?
  end

  test "closed scope finds closed records" do
    @record.close
    assert_includes DummyCloseable.closed, @record
    refute_includes DummyCloseable.open, @record
  end
end
```

### Test in Context

```ruby
# test/models/card_test.rb
class CardTest < ActiveSupport::TestCase
  test "closing card tracks event" do
    card = cards(:logo)

    assert_difference -> { card.events.count }, 1 do
      card.close
    end

    assert_equal "card_closed", card.events.last.action
  end
end
```

## Refactoring Workflow

When extracting a concern:

1. **Identify the pattern** - Find duplicated code across models/controllers
2. **Name the concern** - Use an adjective describing the capability
3. **Create the file** - `app/models/[model]/[concern].rb` or `app/controllers/concerns/[concern].rb`
4. **Move code** - Associations, validations, scopes, methods
5. **Include it** - Add `include ConcernName` to models/controllers
6. **Write tests** - Test concern in isolation and in context
7. **Remove duplication** - Delete the old code from models/controllers

## Common Concern Patterns Catalog

### State Record Concerns
- `Closeable` - has_one :closure, close/reopen methods
- `Publishable` - has_one :publication, publish/unpublish methods
- `Golden` - has_one :goldness, gild/ungild methods
- `NotNowable` - has_one :not_now, postpone/resume methods

### Association Concerns
- `Assignable` - has_many :assignments, assign/unassign methods
- `Watchable` - has_many :watches, watch/unwatch methods
- `Commentable` - has_many :comments, as: :commentable
- `Attachments` - has_many :attachments, as: :attachable

### Behavior Concerns
- `Searchable` - search scopes and methods
- `Positionable` - position attribute and ordering
- `Eventable` - event tracking
- `Broadcastable` - Turbo Stream broadcasting
- `Readable` - read tracking for users

## Commands

```bash
# List concerns
ls app/models/concerns/
ls app/models/card/

# Check usage
bin/rails runner "puts Card.included_modules"

# Search for duplicated code
grep -r "def close" app/models/

# Run tests
bin/rails test test/models/
bin/rails test test/models/concerns/

# With RSpec
bundle exec rspec spec/models/concerns/
```

## Boundaries

### ✅ Always Do

- Extract repeated code into concerns
- Keep concerns focused on one aspect
- Include all related code (associations, scopes, methods)
- Write tests for concerns in isolation and in context
- Use `extend ActiveSupport::Concern`
- Namespace model concerns under the model (`Card::Closeable`)
- Bundle associations, validations, callbacks, and methods together
- Use descriptive adjective names for model concerns

### ⚠️ Ask First

- Before creating concerns that span multiple domains
- Before extracting concerns with complex dependencies
- Before modifying existing concerns used by many models
- Before creating controller concerns that might be better as before_actions

### 🚫 Never Do

- Create god concerns with too many responsibilities
- Use concerns to hide service objects
- Skip the `included do` block for callbacks/associations
- Forget to test concerns in isolation
- Create concerns for one-off code used by a single model
- Mix unrelated behaviors in one concern
- Create concerns without clear naming conventions
