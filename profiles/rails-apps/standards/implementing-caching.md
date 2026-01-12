---
name: implementing-caching
description: Implements HTTP caching with ETags and fragment caching when optimizing application performance
---

You are an expert in implementing aggressive caching strategies for Rails applications.

## Quick Start

Use HTTP caching with `fresh_when` for free 304 Not Modified responses:

```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def show
    @board = Current.account.boards.find(params[:id])
    fresh_when @board
  end

  def index
    @boards = Current.account.boards.includes(:creator)
    fresh_when @boards
  end
end
```

Use fragment caching with Russian doll pattern:

```erb
<!-- app/views/boards/show.html.erb -->
<% cache @board do %>
  <h1><%= @board.name %></h1>

  <% @board.cards.each do |card| %>
    <% cache card do %>
      <%= render card %>
    <% end %>
  <% end %>
<% end %>
```

## Core Principles

**Cache Aggressively, Invalidate Precisely**

1. **HTTP Caching** - Use ETags and `fresh_when` for conditional GET
2. **Russian Doll Caching** - Nested fragment caches with `touch: true`
3. **Solid Cache** - Database-backed (no Redis) for production
4. **Collection Caching** - Use `cache_collection` for lists
5. **Counter Caches** - Avoid N+1 queries in cache keys
6. **Automatic Invalidation** - Use `touch: true` to cascade updates

## Patterns

### Pattern 1: HTTP Caching with ETags

```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def show
    @board = Current.account.boards.find(params[:id])
    # Returns 304 if ETag matches
    fresh_when @board
  end

  def index
    @boards = Current.account.boards.includes(:creator)
    # ETag based on collection
    fresh_when @boards
  end
end

# app/controllers/cards_controller.rb
class CardsController < ApplicationController
  def show
    @board = Current.account.boards.find(params[:board_id])
    @card = @board.cards.find(params[:id])

    # Composite ETag from multiple objects
    fresh_when [@board, @card, Current.user]
  end
end

# app/controllers/api/v1/boards_controller.rb
class Api::V1::BoardsController < Api::V1::BaseController
  def show
    @board = Current.account.boards.find(params[:id])

    # Set both ETag and Last-Modified
    if stale?(@board)
      render json: @board
    end
  end

  def index
    @boards = Current.account.boards.order(updated_at: :desc)

    # Conditional GET with custom cache key
    if stale?(etag: @boards, last_modified: @boards.maximum(:updated_at))
      render json: @boards
    end
  end
end

# Custom ETag incorporating parameters
class ReportsController < ApplicationController
  def activity
    @report_date = params[:date]&.to_date || Date.current
    @activities = Current.account.activities
      .where(created_at: @report_date.beginning_of_day..@report_date.end_of_day)

    # Custom ETag incorporating parameters
    fresh_when etag: [@activities, @report_date, Current.user.timezone]
  end
end
```

### Pattern 2: Russian Doll Caching

```ruby
# app/models/board.rb
class Board < ApplicationRecord
  belongs_to :account
  has_many :cards, dependent: :destroy
end

# app/models/card.rb
class Card < ApplicationRecord
  belongs_to :board, touch: true # Updates board.updated_at
  has_many :comments, dependent: :destroy
end

# app/models/comment.rb
class Comment < ApplicationRecord
  belongs_to :card, touch: true # Updates card.updated_at → board.updated_at
end
```

```erb
<!-- app/views/boards/show.html.erb -->
<% cache @board do %>
  <h1><%= @board.name %></h1>
  <p><%= @board.description %></p>

  <div class="columns">
    <% @board.columns.each do |column| %>
      <% cache column do %>
        <div class="column">
          <h2><%= column.name %></h2>

          <div class="cards">
            <% column.cards.each do |card| %>
              <% cache card do %>
                <%= render card %>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>
    <% end %>
  </div>
<% end %>
```

### Pattern 3: Collection Caching

```ruby
# app/views/boards/index.html.erb
<div class="boards">
  <!-- Cache each board individually -->
  <% cache_collection @boards, partial: "boards/board" %>
</div>

# app/views/boards/_board.html.erb
<div class="board" id="<%= dom_id(board) %>">
  <h2><%= board.name %></h2>
  <p><%= board.description %></p>

  <div class="meta">
    <%= board.cards.count %> cards
  </div>
</div>

# Alternative: Manual cache per item
<div class="boards">
  <% @boards.each do |board| %>
    <% cache board do %>
      <%= render "boards/board", board: board %>
    <% end %>
  <% end %>
</div>
```

With counter cache:

```ruby
# app/models/board.rb
class Board < ApplicationRecord
  has_many :cards, dependent: :destroy

  # Avoid N+1 queries in cache keys
  def cache_key_with_version
    "#{cache_key}/cards-#{cards_count}-#{updated_at.to_i}"
  end
end

# app/models/card.rb
class Card < ApplicationRecord
  belongs_to :board, counter_cache: true, touch: true
end

# db/migrate/xxx_add_cards_count_to_boards.rb
class AddCardsCountToBoards < ActiveRecord::Migration[8.0]
  def change
    add_column :boards, :cards_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up { Board.find_each { |b| Board.reset_counters(b.id, :cards) } }
    end
  end
end
```

### Pattern 4: Fragment Caching with Custom Keys

```erb
<!-- app/views/boards/show.html.erb -->
<!-- Cache with multiple dependencies -->
<% cache ["board_header", @board, Current.user] do %>
  <div class="board-header">
    <h1><%= @board.name %></h1>

    <% if Current.user.can_edit?(@board) %>
      <%= link_to "Edit", edit_board_path(@board) %>
    <% end %>
  </div>
<% end %>

<!-- Cache with custom expiration -->
<% cache ["board_stats", @board], expires_in: 15.minutes do %>
  <div class="board-stats">
    <div class="stat">
      <span class="label">Cards</span>
      <span class="value"><%= @board.cards.count %></span>
    </div>

    <div class="stat">
      <span class="label">Comments</span>
      <span class="value"><%= @board.cards.joins(:comments).count %></span>
    </div>
  </div>
<% end %>

<!-- Conditional caching -->
<% cache_if @enable_caching, @board do %>
  <%= render @board %>
<% end %>

<% cache_unless Current.user.admin?, @board do %>
  <%= render @board %>
<% end %>
```

### Pattern 5: Low-Level Caching for Expensive Operations

```ruby
# app/models/board.rb
class Board < ApplicationRecord
  def statistics
    Rails.cache.fetch([self, "statistics"], expires_in: 1.hour) do
      {
        total_cards: cards.count,
        completed_cards: cards.joins(:closure).count,
        total_comments: cards.joins(:comments).count,
        active_members: cards.joins(:assignments).distinct.count(:user_id)
      }
    end
  end

  def card_distribution
    Rails.cache.fetch([self, "card_distribution"], expires_in: 30.minutes) do
      columns.includes(:cards).map { |column|
        {
          name: column.name,
          count: column.cards.count,
          percentage: (column.cards.count.to_f / cards.count * 100).round(1)
        }
      }
    end
  end

  def recent_activity_summary
    Rails.cache.fetch(
      [self, "activity_summary", Date.current],
      expires_in: 5.minutes
    ) do
      activities.where(created_at: 24.hours.ago..)
        .group(:subject_type)
        .count
    end
  end
end

# app/models/account.rb
class Account < ApplicationRecord
  def monthly_metrics(month = Date.current)
    Rails.cache.fetch(
      [self, "monthly_metrics", month.beginning_of_month],
      expires_in: 1.day
    ) do
      {
        boards_created: boards.where(created_at: month.all_month).count,
        cards_created: cards.where(created_at: month.all_month).count,
        comments_added: comments.where(created_at: month.all_month).count,
        active_users: activities.where(created_at: month.all_month)
          .distinct.count(:creator_id)
      }
    end
  end

  def search_results(query)
    Rails.cache.fetch(
      ["search", self, query.downcase.strip],
      expires_in: 10.minutes
    ) do
      {
        boards: boards.where("name ILIKE ?", "%#{query}%").limit(10),
        cards: cards.where("title ILIKE ?", "%#{query}%").limit(20),
        comments: comments.where("body ILIKE ?", "%#{query}%").limit(20)
      }
    end
  end
end

# Cache with race condition protection
class Board < ApplicationRecord
  def expensive_calculation
    Rails.cache.fetch(
      [self, "expensive_calculation"],
      expires_in: 1.hour,
      race_condition_ttl: 10.seconds
    ) do
      calculate_complex_metrics
    end
  end
end
```

### Pattern 6: Cache Invalidation

```ruby
# app/models/board.rb
class Board < ApplicationRecord
  has_many :cards, dependent: :destroy

  after_update :clear_statistics_cache, if: :significant_change?

  def clear_statistics_cache
    Rails.cache.delete([self, "statistics"])
    Rails.cache.delete([self, "card_distribution"])
  end

  def refresh_cache
    clear_statistics_cache
    statistics # Regenerate
    card_distribution # Regenerate
  end

  private

  def significant_change?
    saved_change_to_name? || saved_change_to_description?
  end
end

# app/models/card.rb
class Card < ApplicationRecord
  belongs_to :board, touch: true

  after_create_commit :clear_board_caches
  after_destroy_commit :clear_board_caches

  private

  def clear_board_caches
    Rails.cache.delete([board, "statistics"])
    Rails.cache.delete([board, "card_distribution"])
  end
end

# app/models/cache_sweeper.rb
class CacheSweeper
  def self.clear_board_caches(board)
    Rails.cache.delete([board, "statistics"])
    Rails.cache.delete([board, "card_distribution"])
    Rails.cache.delete([board, "activity_summary", Date.current])

    # Clear related caches
    board.account.tap do |account|
      Rails.cache.delete([account, "monthly_metrics", Date.current.beginning_of_month])
    end
  end

  def self.clear_account_caches(account)
    Rails.cache.delete_matched("accounts/#{account.id}/*")
  end
end

# Usage in models
class Board < ApplicationRecord
  after_update :sweep_caches

  private

  def sweep_caches
    CacheSweeper.clear_board_caches(self)
  end
end
```

### Pattern 7: Solid Cache Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Use Solid Cache (database-backed)
  config.cache_store = :solid_cache_store
end

# config/environments/development.rb
Rails.application.configure do
  # Use memory store in development
  config.cache_store = :memory_store, { size: 64.megabytes }

  # Or use Solid Cache in development too
  # config.cache_store = :solid_cache_store
end

# config/environments/test.rb
Rails.application.configure do
  # Use null store in tests (no caching)
  config.cache_store = :null_store

  # Or use memory store to test caching behavior
  # config.cache_store = :memory_store
end
```

## Commands

```bash
# Install Solid Cache (already in Rails 8)
rails solid_cache:install

# Generate cache migrations
rails generate solid_cache:install

# Run cache migrations
rails db:migrate

# Clear cache
rails cache:clear

# Cache stats
rails solid_cache:stats
```

## Testing

```ruby
# test/models/board_test.rb
require "test_helper"

class BoardTest < ActiveSupport::TestCase
  test "touching card updates board updated_at" do
    board = boards(:design)
    card = cards(:one)

    assert_changes -> { board.reload.updated_at } do
      card.touch
    end
  end

  test "statistics are cached" do
    board = boards(:design)

    # First call calculates
    assert_queries(5) { board.statistics }

    # Second call uses cache
    assert_no_queries { board.statistics }
  end

  test "cache key includes updated_at" do
    board = boards(:design)
    original_key = board.cache_key_with_version

    board.touch

    assert_not_equal original_key, board.cache_key_with_version
  end
end

# test/controllers/boards_controller_test.rb
require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  test "returns 304 when board unchanged" do
    board = boards(:design)

    get board_url(board)
    assert_response :success
    etag = response.headers["ETag"]

    get board_url(board), headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end

  test "returns 200 when board updated" do
    board = boards(:design)

    get board_url(board)
    etag = response.headers["ETag"]

    board.touch

    get board_url(board), headers: { "If-None-Match" => etag }
    assert_response :success
  end
end
```

## Boundaries

### Always Do:
- Use HTTP caching with `fresh_when` for index and show actions
- Use `touch: true` on associations for automatic cache invalidation
- Use Russian doll caching (nested fragment caches)
- Use Solid Cache in production (database-backed, no Redis)
- Cache keys should include `updated_at` timestamps
- Use counter caches for counts
- Eager load associations to prevent N+1 queries
- Use `cache_collection` for lists
- Include `expires_in` for time-based expiration
- Scope cache keys to account in multi-tenant apps

### Ask First:
- Whether to cache user-specific content
- Cache expiration times (balance freshness vs performance)
- Whether to warm caches in background jobs
- Cache versioning strategies for gradual rollouts
- Custom cache key strategies
- Cache storage limits and cleanup policies

### Never Do:
- Use Redis for caching (use Solid Cache - database-backed)
- Cache without considering invalidation strategy
- Forget `touch: true` when using Russian doll caching
- Cache CSRF tokens or sensitive user data
- Use generic cache keys without version/timestamp
- Cache in test environment (use :null_store)
- Manually invalidate nested caches (use touch cascade)
- Cache without setting `expires_in` for time-sensitive data
- Use fragment caching without understanding the cache key
- Cache across account boundaries in multi-tenant apps
