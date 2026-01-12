---
name: writing-queries
description: Creates Query Objects for complex database queries with N+1 prevention and eager loading
---

# Writing Queries Skill

Expert in Query Object pattern for Rails applications with focus on performance and reusability.

## Quick Start

Query Objects encapsulate complex database queries into focused, testable classes. Use them when:
- Queries have multiple conditions
- Queries are used in multiple places
- Search and filtering logic is complex
- You need to prevent N+1 queries
- Queries need to be tested independently

**Basic Usage:**
```ruby
# In controller
@entities = Entities::SearchQuery.new.call(params).page(params[:page])

# Or with class method
@entities = Entities::SearchQuery.call(params)
```

## Core Principles

### 1. Return ActiveRecord Relations
Always return relations (not arrays) so results remain chainable:
```ruby
# Good - chainable
Entities::SearchQuery.new.call(params).page(1).per(20)

# Bad - not chainable
results.page(1)  # Error: Array doesn't have #page
```

### 2. Prevent N+1 Queries
ALWAYS use `includes`, `preload`, or `eager_load`:
```ruby
def default_relation
  Entity.includes(:user, :submissions)  # Preload associations
end
```

### 3. Sanitize User Input
Prevent SQL injection by sanitizing all user input:
```ruby
relation.where('name ILIKE ?', "%#{sanitize_sql_like(query)}%")
```

### 4. Single Responsibility
Each query object should encapsulate ONE type of query (e.g., search, reporting, filtering).

## Patterns

### ApplicationQuery Base Class

```ruby
# app/queries/application_query.rb
class ApplicationQuery
  attr_reader :relation

  def initialize(relation = default_relation)
    @relation = relation
  end

  def call(params = {})
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  def self.call(*args)
    new.call(*args)
  end

  private

  def default_relation
    raise NotImplementedError, "#{self.class} must implement #default_relation"
  end

  def sanitize_sql_like(string)
    ActiveRecord::Base.sanitize_sql_like(string)
  end
end
```

### Pattern 1: Search Query with Multiple Filters

```ruby
# app/queries/entities/search_query.rb
module Entities
  class SearchQuery < ApplicationQuery
    def call(filters = {})
      relation
        .then { |rel| filter_by_status(rel, filters[:status]) }
        .then { |rel| filter_by_user(rel, filters[:user_id]) }
        .then { |rel| search(rel, filters[:q]) }
        .then { |rel| sort(rel, filters[:sort]) }
    end

    private

    def default_relation
      Entity.includes(:user)
    end

    def filter_by_status(relation, status)
      return relation if status.blank?
      relation.where(status: status)
    end

    def filter_by_user(relation, user_id)
      return relation if user_id.blank?
      relation.where(user_id: user_id)
    end

    def search(relation, query)
      return relation if query.blank?

      relation.where(
        'name ILIKE :q OR description ILIKE :q',
        q: "%#{sanitize_sql_like(query)}%"
      )
    end

    def sort(relation, sort_param)
      case sort_param
      when 'name' then relation.order(name: :asc)
      when 'oldest' then relation.order(created_at: :asc)
      else relation.order(created_at: :desc)
      end
    end
  end
end
```

**RSpec Test:**
```ruby
# spec/queries/entities/search_query_spec.rb
require 'rails_helper'

RSpec.describe Entities::SearchQuery do
  describe '#call' do
    subject(:results) { described_class.new.call(filters) }

    let!(:published) { create(:entity, status: 'published', name: 'Alpha') }
    let!(:draft) { create(:entity, status: 'draft', name: 'Beta') }
    let!(:archived) { create(:entity, status: 'archived', name: 'Gamma') }

    context 'without filters' do
      let(:filters) { {} }

      it 'returns all entities' do
        expect(results).to contain_exactly(published, draft, archived)
      end

      it 'orders by created_at desc' do
        expect(results.first).to eq(archived)
      end
    end

    context 'with status filter' do
      let(:filters) { { status: 'published' } }

      it 'returns only published entities' do
        expect(results).to contain_exactly(published)
      end
    end

    context 'with search query' do
      let(:filters) { { q: 'alpha' } }

      it 'returns matching entities' do
        expect(results).to contain_exactly(published)
      end

      it 'is case insensitive' do
        filters[:q] = 'ALPHA'
        expect(results).to contain_exactly(published)
      end
    end

    context 'with multiple filters' do
      let(:filters) { { status: 'published', q: 'alpha' } }

      it 'applies all filters' do
        expect(results).to contain_exactly(published)
      end
    end
  end
end
```

### Pattern 2: Advanced Search with Whitelists

```ruby
# app/queries/posts/search_query.rb
module Posts
  class SearchQuery < ApplicationQuery
    ALLOWED_STATUSES = %w[draft published archived].freeze
    ALLOWED_SORT_FIELDS = %w[title created_at updated_at].freeze

    def call(filters = {})
      relation
        .then { |rel| filter_by_status(rel, filters[:status]) }
        .then { |rel| filter_by_author(rel, filters[:author_id]) }
        .then { |rel| filter_by_category(rel, filters[:category_id]) }
        .then { |rel| filter_by_date_range(rel, filters[:from_date], filters[:to_date]) }
        .then { |rel| search_text(rel, filters[:q]) }
        .then { |rel| sort(rel, filters[:sort_by], filters[:sort_dir]) }
    end

    private

    def default_relation
      Post.includes(:author, :category)
    end

    def filter_by_status(relation, status)
      return relation if status.blank?
      return relation unless ALLOWED_STATUSES.include?(status)

      relation.where(status: status)
    end

    def filter_by_author(relation, author_id)
      return relation if author_id.blank?
      relation.where(author_id: author_id)
    end

    def filter_by_category(relation, category_id)
      return relation if category_id.blank?
      relation.where(category_id: category_id)
    end

    def filter_by_date_range(relation, from_date, to_date)
      relation = relation.where('created_at >= ?', from_date) if from_date.present?
      relation = relation.where('created_at <= ?', to_date) if to_date.present?
      relation
    end

    def search_text(relation, query)
      return relation if query.blank?

      sanitized = sanitize_sql_like(query)
      relation.where(
        'title ILIKE :q OR body ILIKE :q',
        q: "%#{sanitized}%"
      )
    end

    def sort(relation, field, direction)
      field = 'created_at' unless ALLOWED_SORT_FIELDS.include?(field)
      direction = direction == 'asc' ? :asc : :desc

      relation.order(field => direction)
    end
  end
end
```

### Pattern 3: Reporting Query with Aggregations

```ruby
# app/queries/orders/revenue_report_query.rb
module Orders
  class RevenueReportQuery < ApplicationQuery
    def call(start_date:, end_date:, group_by: :day)
      relation
        .where(created_at: start_date..end_date)
        .where(status: %w[paid delivered])
        .group_by_period(group_by, :created_at)
        .select(
          date_trunc_sql(group_by),
          'COUNT(*) as orders_count',
          'SUM(total) as total_revenue',
          'AVG(total) as average_order_value'
        )
    end

    private

    def default_relation
      Order.all
    end

    def date_trunc_sql(period)
      case period
      when :hour then "DATE_TRUNC('hour', created_at) as period"
      when :day then "DATE_TRUNC('day', created_at) as period"
      when :week then "DATE_TRUNC('week', created_at) as period"
      when :month then "DATE_TRUNC('month', created_at) as period"
      else "DATE_TRUNC('day', created_at) as period"
      end
    end
  end
end
```

### Pattern 4: Complex Join Query

```ruby
# app/queries/users/active_users_query.rb
module Users
  class ActiveUsersQuery < ApplicationQuery
    def call(days: 30)
      relation
        .joins(:posts, :comments)
        .where('posts.created_at >= ? OR comments.created_at >= ?', days.days.ago, days.days.ago)
        .distinct
        .select(
          'users.*',
          'COUNT(DISTINCT posts.id) as posts_count',
          'COUNT(DISTINCT comments.id) as comments_count'
        )
        .group('users.id')
        .having('COUNT(DISTINCT posts.id) > 0 OR COUNT(DISTINCT comments.id) > 0')
        .order('posts_count + comments_count DESC')
    end

    private

    def default_relation
      User.all
    end
  end
end
```

**Testing Complex Queries:**
```ruby
# spec/queries/users/active_users_query_spec.rb
require 'rails_helper'

RSpec.describe Users::ActiveUsersQuery do
  describe '#call' do
    subject(:results) { described_class.new.call(days: 30) }

    let!(:active_user) { create(:user) }
    let!(:inactive_user) { create(:user) }
    let!(:recently_active_user) { create(:user) }

    before do
      create(:post, user: active_user, created_at: 10.days.ago)
      create(:comment, user: active_user, created_at: 5.days.ago)
      create(:post, user: inactive_user, created_at: 60.days.ago)
      create(:comment, user: recently_active_user, created_at: 2.days.ago)
    end

    it 'returns users active in the last 30 days' do
      expect(results).to contain_exactly(active_user, recently_active_user)
    end

    it 'excludes inactive users' do
      expect(results).not_to include(inactive_user)
    end

    it 'orders by activity count' do
      expect(results.first).to eq(active_user)
    end

    it 'includes activity counts' do
      user = results.find { |u| u.id == active_user.id }
      expect(user.posts_count).to eq(1)
      expect(user.comments_count).to eq(1)
    end
  end
end
```

### Pattern 5: Scope-Based Query

```ruby
# app/queries/entities/dashboard_query.rb
module Entities
  class DashboardQuery < ApplicationQuery
    def call(user:, filters: {})
      relation
        .for_user(user)
        .then { |rel| apply_visibility(rel, filters[:visibility]) }
        .then { |rel| apply_time_range(rel, filters[:time_range]) }
        .recent
        .with_stats
    end

    private

    def default_relation
      Entity.includes(:user, :submissions)
    end

    def apply_visibility(relation, visibility)
      case visibility
      when 'mine'
        relation.where(user: user)
      when 'public'
        relation.where(visibility: 'public')
      else
        relation
      end
    end

    def apply_time_range(relation, time_range)
      case time_range
      when 'today'
        relation.where('created_at >= ?', Time.current.beginning_of_day)
      when 'week'
        relation.where('created_at >= ?', 1.week.ago)
      when 'month'
        relation.where('created_at >= ?', 1.month.ago)
      else
        relation
      end
    end
  end
end
```

### Pattern 6: Pagination-Aware Query

```ruby
# app/queries/products/catalog_query.rb
module Products
  class CatalogQuery < ApplicationQuery
    def call(filters = {}, page: 1, per_page: 20)
      relation
        .then { |rel| filter_by_category(rel, filters[:category]) }
        .then { |rel| filter_by_price_range(rel, filters[:min_price], filters[:max_price]) }
        .then { |rel| filter_by_availability(rel, filters[:in_stock]) }
        .then { |rel| sort(rel, filters[:sort]) }
        .page(page)
        .per(per_page)
    end

    private

    def default_relation
      Product.includes(:category, :reviews)
    end

    def filter_by_category(relation, category_id)
      return relation if category_id.blank?
      relation.where(category_id: category_id)
    end

    def filter_by_price_range(relation, min_price, max_price)
      relation = relation.where('price >= ?', min_price) if min_price.present?
      relation = relation.where('price <= ?', max_price) if max_price.present?
      relation
    end

    def filter_by_availability(relation, in_stock)
      return relation if in_stock.blank?

      case in_stock
      when 'true', true
        relation.where('stock > 0')
      when 'false', false
        relation.where(stock: 0)
      else
        relation
      end
    end

    def sort(relation, sort_param)
      case sort_param
      when 'price_asc' then relation.order(price: :asc)
      when 'price_desc' then relation.order(price: :desc)
      when 'name' then relation.order(name: :asc)
      when 'popular' then relation.order(views_count: :desc)
      else relation.order(created_at: :desc)
      end
    end
  end
end
```

## Commands

### Testing Queries

```bash
# Run all query tests
bundle exec rspec spec/queries/

# Run specific query test
bundle exec rspec spec/queries/entities/search_query_spec.rb

# Run specific test case (line number)
bundle exec rspec spec/queries/entities/search_query_spec.rb:25

# Run with detailed output
bundle exec rspec --format documentation spec/queries/
```

### Linting Queries

```bash
# Auto-fix query code
bundle exec rubocop -a app/queries/

# Auto-fix query specs
bundle exec rubocop -a spec/queries/
```

### Manual Testing & Performance

```bash
# Open Rails console
bin/rails console

# Test query manually
results = Entities::SearchQuery.new.call(status: 'published')

# Check SQL generated
results.to_sql

# Enable SQL logging
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Run query and see SQL
Entities::SearchQuery.new.call(status: 'published').load
```

## N+1 Query Prevention

### Use `includes` for Preloading

```ruby
# Bad - N+1 queries
def default_relation
  Entity.all
end

# Good - Preload associations
def default_relation
  Entity.includes(:user, :submissions)
end
```

### Testing for N+1 Queries

```ruby
# spec/queries/posts/search_query_spec.rb
require 'rails_helper'

RSpec.describe Posts::SearchQuery do
  describe '#call' do
    let!(:posts) { create_list(:post, 3, :with_author, :with_category) }

    it 'avoids N+1 queries' do
      query = described_class.new

      # First call to load associations
      query.call({})

      expect {
        results = query.call({})
        results.each do |post|
          post.author.name
          post.category.name
        end
      }.not_to exceed_query_limit(3)
    end
  end
end
```

## Query vs Scope

### Use Scopes For:
- Simple, reusable conditions
- Single-purpose filters
- Model-level concerns

```ruby
# Good use of scope
class Entity < ApplicationRecord
  scope :published, -> { where(status: 'published') }
  scope :recent, -> { order(created_at: :desc) }
end
```

### Use Query Objects For:
- Complex queries with multiple conditions
- Queries with business logic
- Search and filtering logic
- Queries used in multiple places
- Queries that need independent testing

## Boundaries

### Always Do:
- Write RSpec tests for every query
- Return ActiveRecord relations (not arrays)
- Use `includes` to prevent N+1 queries
- Sanitize user input with `sanitize_sql_like`
- Use parameterized queries
- Keep queries focused (SRP)
- Use `then` for chainable filters

### Ask First Before:
- Writing raw SQL (consider if ActiveRecord can handle it)
- Creating complex subqueries
- Modifying ApplicationQuery
- Adding database-specific features

### Never Do:
- Put business logic in queries (use services)
- Skip writing tests
- Use string interpolation in SQL
- Return arrays instead of relations
- Ignore N+1 queries
- Create "God queries" that do everything
- Modify data in queries (queries are read-only)

## Controller Integration

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  def index
    @entities = Entities::SearchQuery
      .new
      .call(search_params)
      .page(params[:page])
  end

  private

  def search_params
    params.permit(:status, :user_id, :q, :sort)
  end
end
```

## Tech Stack

- **Ruby:** 3.3
- **Rails:** 8.1
- **Database:** PostgreSQL
- **Testing:** RSpec, FactoryBot
- **Pattern:** Query Object pattern with eager loading
