---
name: using-state-records
description: Implements the state-as-records pattern instead of boolean columns, creating rich state models that track who changed state, when it changed, and why it changed
---

# Using State Records

Models state as separate records instead of boolean columns. Creates rich state tracking that captures who, when, and why state changed.

## Quick Start

**Instead of a boolean:**
```ruby
# ❌ DON'T DO THIS
class Card < ApplicationRecord
  # closed: boolean column
  def close
    update!(closed: true, closed_at: Time.current)
  end
end
```

**Use a state record:**
```ruby
# ✅ DO THIS

# Generate state model
bin/rails generate model Closure card:references:uuid user:references:uuid account:references:uuid

# State record model
class Closure < ApplicationRecord
  belongs_to :card, touch: true
  belongs_to :user, optional: true
  belongs_to :account, default: -> { card.account }
  validates :card, uniqueness: true
end

# Model with concern
class Card < ApplicationRecord
  include Closeable
  has_one :closure, dependent: :destroy

  def close(user: Current.user)
    create_closure!(user: user)
  end

  def closed?
    closure.present?
  end

  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }
end
```

## Core Principles

### 1. State as Records, Not Booleans

Boolean columns give you:
- ✓ Current state (open/closed)
- ✗ When it changed, Who changed it, Why it changed, Change history

State records give you:
- ✓ Current state (closure.present?)
- ✓ When (closure.created_at), Who (closure.user), Why (closure.reason), History (via events)

### 2. Noun Forms for State Records

Use nouns: `Closure`, `Publication`, `Goldness`, `NotNow`, `Archival`
Not adjectives: ~~`Closed`~~, ~~`Published`~~, ~~`Golden`~~

### 3. One State Model Per Boolean

- `closed: boolean` → `Closure` model
- `published: boolean` → `Publication` model
- `golden: boolean` → `Goldness` model

### 4. Use where.missing for Negative Scopes

```ruby
scope :open, -> { where.missing(:closure) }
scope :private, -> { where.missing(:publication) }
scope :not_golden, -> { where.missing(:goldness) }
```

### 5. Always Include Unique Index

```ruby
add_index :closures, :card_id, unique: true
```

## Patterns

### Simple Toggle State (Closure)

**Migration:**
```ruby
class CreateClosures < ActiveRecord::Migration[8.2]
  def change
    create_table :closures, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid
      t.references :user, null: true, type: :uuid
      t.timestamps
    end
    add_index :closures, :card_id, unique: true
  end
end
```

**State record model:**
```ruby
class Closure < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :user, optional: true
  validates :card, uniqueness: true

  after_create_commit :notify_watchers
  after_destroy_commit :notify_watchers

  private
  def notify_watchers
    card.notify_watchers_later
  end
end
```

**Concern:**
```ruby
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
end
```

### State with Metadata (Publication)

**Migration:**
```ruby
class CreateBoardPublications < ActiveRecord::Migration[8.2]
  def change
    create_table :board_publications, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :board, null: false, type: :uuid
      t.string :key, null: false
      t.text :description
      t.timestamps
    end
    add_index :board_publications, :board_id, unique: true
    add_index :board_publications, :key, unique: true
  end
end
```

**State record with metadata:**
```ruby
class Board::Publication < ApplicationRecord
  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true
  has_secure_token :key
  validates :board, uniqueness: true

  def public_url
    Rails.application.routes.url_helpers.public_board_url(key)
  end
end
```

**Concern:**
```ruby
module Board::Publishable
  extend ActiveSupport::Concern

  included do
    has_one :publication, dependent: :destroy
    scope :published, -> { joins(:publication) }
    scope :private, -> { where.missing(:publication) }
  end

  def publish(description: nil)
    create_publication!(description: description)
    track_event "board_published"
  end

  def unpublish
    publication&.destroy!
    track_event "board_unpublished"
  end

  def published?
    publication.present?
  end

  def public_url
    publication&.public_url
  end
end
```

### Marker State (Goldness)

**Migration:**
```ruby
class CreateCardGoldnesses < ActiveRecord::Migration[8.2]
  def change
    create_table :card_goldnesses, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid
      t.timestamps
    end
    add_index :card_goldnesses, :card_id, unique: true
  end
end
```

**Concern:**
```ruby
module Card::Golden
  extend ActiveSupport::Concern

  included do
    has_one :goldness, dependent: :destroy
    scope :golden, -> { joins(:goldness) }
    scope :not_golden, -> { where.missing(:goldness) }
    scope :with_golden_first, -> {
      left_outer_joins(:goldness)
        .select("cards.*", "card_goldnesses.created_at as golden_at")
        .order(Arel.sql("golden_at IS NULL, golden_at DESC"))
    }
  end

  def gild
    create_goldness! unless golden?
    track_event "card_gilded"
  end

  def ungild
    goldness&.destroy!
    track_event "card_ungilded"
  end

  def golden?
    goldness.present?
  end
end
```

### State with Reason (Archival)

**Migration:**
```ruby
class CreateCardArchivals < ActiveRecord::Migration[8.2]
  def change
    create_table :card_archivals, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid
      t.references :user, null: true, type: :uuid
      t.text :reason
      t.timestamps
    end
    add_index :card_archivals, :card_id, unique: true
  end
end
```

**Concern:**
```ruby
module Card::Archivable
  extend ActiveSupport::Concern

  included do
    has_one :archival, dependent: :destroy
    scope :archived, -> { joins(:archival) }
    scope :active, -> { where.missing(:archival) }
  end

  def archive(user: Current.user, reason: nil)
    create_archival!(user: user, reason: reason)
    track_event "card_archived", user: user, particulars: { reason: reason }
  end

  def unarchive
    archival&.destroy!
    track_event "card_unarchived"
  end

  def archived?
    archival.present?
  end

  def archival_reason
    archival&.reason
  end
end
```

## Query Patterns

### Finding Records by State

```ruby
Card.open                    # where.missing(:closure)
Card.closed                  # joins(:closure)
Board.published              # joins(:publication)
Board.private                # where.missing(:publication)
Card.golden                  # joins(:goldness)
Card.not_golden             # where.missing(:goldness)
```

### Complex State Combinations

```ruby
# Active cards (open, published, not postponed)
scope :active, -> { open.published.where.missing(:not_now) }

# Actionable cards
scope :actionable, -> {
  where.missing(:closure).where.missing(:not_now).where.missing(:archival)
}

# Important open cards
scope :important_open, -> {
  open.joins(:goldness).order("card_goldnesses.created_at DESC")
}
```

### Sorting by State

```ruby
# Golden cards first
scope :with_golden_first, -> {
  left_outer_joins(:goldness)
    .select("cards.*", "card_goldnesses.created_at as golden_at")
    .order(Arel.sql("golden_at IS NULL, golden_at DESC"))
}

# Recently closed first
scope :recently_closed, -> {
  closed.joins(:closure).order("closures.created_at DESC")
}

# Cards closed by specific user
scope :closed_by, ->(user) {
  joins(:closure).where(closures: { user: user })
}
```

## Controller Patterns

### Singular Resource Controller

```ruby
# config/routes.rb
resources :cards do
  resource :closure, only: [:create, :destroy], module: :cards
  resource :goldness, only: [:create, :destroy], module: :cards
end

# app/controllers/cards/closures_controller.rb
class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    @card.close(user: Current.user)
    render_card_replacement
  end

  def destroy
    @card.reopen
    render_card_replacement
  end
end
```

### With Form Data

```ruby
class Boards::PublicationsController < ApplicationController
  include BoardScoped

  def create
    @board.publish(description: publication_params[:description])
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @board, notice: "Board published" }
    end
  end

  def destroy
    @board.unpublish
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @board, notice: "Board unpublished" }
    end
  end

  private
  def publication_params
    params.fetch(:publication, {}).permit(:description)
  end
end
```

## View Patterns

### Conditional Rendering

```erb
<% if card.closed? %>
  <div class="card--closed">
    Closed <%= time_ago_in_words(card.closed_at) %> ago
    <% if card.closed_by %>by <%= card.closed_by.name %><% end %>
    <%= button_to "Reopen", card_closure_path(card), method: :delete %>
  </div>
<% else %>
  <%= button_to "Close", card_closure_path(card), method: :post %>
<% end %>
```

### Toggle Buttons

```erb
<%= button_to card_goldness_path(card),
    method: card.golden? ? :delete : :post,
    class: "toggle-golden",
    data: { turbo_frame: dom_id(card) } do %>
  <%= card.golden? ? "★ Ungild" : "☆ Gild" %>
<% end %>
```

### State Badges

```erb
<div class="card-badges">
  <% if card.golden? %>
    <span class="badge badge--golden">★ Important</span>
  <% end %>
  <% if card.postponed? %>
    <span class="badge badge--postponed">Not Now</span>
  <% end %>
  <% if card.closed? %>
    <span class="badge badge--closed">Closed</span>
  <% end %>
</div>
```

## Common State Record Examples

**Card states:** `Closure`, `Card::Goldness`, `Card::NotNow`, `Card::Archival`
**Board states:** `Board::Publication`, `Board::Archival`, `Board::Lock`
**User states:** `User::Suspension`, `User::Activation`, `User::Verification`
**Project states:** `Project::Completion`, `Project::Hold`, `Project::Cancellation`

## Migration from Boolean to State Record

### Step 1: Create State Record

```ruby
class CreateClosures < ActiveRecord::Migration[8.2]
  def change
    create_table :closures, id: :uuid do |t|
      t.references :account, null: false, type: :uuid
      t.references :card, null: false, type: :uuid
      t.references :user, null: true, type: :uuid
      t.timestamps
    end
    add_index :closures, :card_id, unique: true
  end
end
```

### Step 2: Backfill Existing Data

```ruby
class BackfillClosuresFromBoolean < ActiveRecord::Migration[8.2]
  def up
    Card.where(closed: true).find_each do |card|
      Closure.create!(
        card: card,
        account: card.account,
        created_at: card.closed_at || card.updated_at
      )
    end
  end

  def down
    Closure.destroy_all
  end
end
```

### Step 3: Update Model Code

Add the concern to your model:
```ruby
class Card < ApplicationRecord
  include Closeable
end
```

### Step 4: Remove Boolean Column (After Verification)

```ruby
class RemoveClosedFromCards < ActiveRecord::Migration[8.2]
  def change
    remove_column :cards, :closed, :boolean
    remove_column :cards, :closed_at, :datetime
  end
end
```

## Commands

```bash
# Generate state model
bin/rails generate model Closure card:references:uuid user:references:uuid account:references:uuid

# Run migration
bin/rails db:migrate

# Test in console
bin/rails console
> Card.open.count
> Card.closed.count

# Run tests
bin/rails test test/models/
```

## When to Use State Records vs Booleans

### Use State Records When:
- ✅ You need to know when state changed
- ✅ You need to know who changed it
- ✅ You might need to store metadata (reason, notes)
- ✅ State changes are important business events
- ✅ You need to query "recently closed" or "closed by X"

### Use Booleans When:
- ✅ State is purely technical (cached, processed)
- ✅ Timestamp/actor doesn't matter
- ✅ Performance is critical (millions of rows, frequent updates)
- ✅ State changes are not business events

### Examples by Category

**State records:** closed, published, archived, suspended, verified, activated, approved, pinned, golden, featured, postponed, on_hold, cancelled

**Booleans:** admin (role), cached (technical flag), processed (job status), visible (simple toggle)

## Boundaries

### ✅ Always Do

- Create state record for business-meaningful states
- Track who and when for state changes
- Use `where.missing` for negative scopes
- Add unique index on parent_id
- Include account_id for multi-tenancy
- Touch parent record when state changes
- Write tests for state transitions
- Use noun forms for state record names (Closure, not Closed)

### ⚠️ Ask First

- Before using boolean columns for business state
- Before creating state records without timestamps
- Before adding complex metadata to state records (might need separate model)
- Before creating state records for purely technical flags

### 🚫 Never Do

- Use booleans for important business state
- Skip who/when tracking for business state changes
- Forget to scope states by account in multi-tenant apps
- Create multiple state records per parent (use `has_one` with unique index)
- Skip event tracking for state changes
- Forget to touch parent record
- Name state records as adjectives (use nouns like `Closure`, not `Closed`)
