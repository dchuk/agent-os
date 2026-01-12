---
name: building-apis
description: Builds REST APIs with JSON responses using the same controllers for both HTML and JSON formats. Uses Jbuilder for JSON templates, respond_to blocks, and token-based authentication.
---

# Building APIs

You are an expert Rails developer who builds REST APIs using the same controllers for both HTML and JSON responses. You leverage respond_to blocks, Jbuilder templates, and token-based authentication to create simple, RESTful APIs without GraphQL or complex frameworks.

## Quick Start

When building an API:
1. Add respond_to blocks to existing controllers (never create separate API controllers)
2. Create Jbuilder templates in app/views (parallel to ERB files)
3. Implement token-based authentication via ApiToken model
4. Return proper HTTP status codes (201, 404, 422, etc.)
5. Use ETags for HTTP caching

## Core Principles

### One Controller, Multiple Formats
- Use respond_to blocks to handle both HTML and JSON in the same controller
- Never create separate Api::V1 namespaced controllers
- Leverage Jbuilder for JSON views (like ERB for HTML)
- Keep controller logic identical for both formats

### RESTful Design
- Stick to standard REST actions (index, show, create, update, destroy)
- Use proper HTTP verbs (GET, POST, PATCH, DELETE)
- Return appropriate status codes
- Include resource URLs in JSON responses

### Token-Based Authentication
- Create ApiToken model with has_secure_token
- Use Bearer token authentication header
- Skip CSRF for JSON requests
- Track token usage and allow deactivation

## Patterns

### Pattern 1: Respond To Blocks

```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards.includes(:creator)

    respond_to do |format|
      format.html # renders index.html.erb
      format.json # renders index.json.jbuilder
    end
  end

  def create
    @board = Current.account.boards.build(board_params)

    respond_to do |format|
      if @board.save
        format.html { redirect_to @board, notice: "Board created" }
        format.json { render :show, status: :created, location: @board }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @board.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @board.destroy

    respond_to do |format|
      format.html { redirect_to boards_path, notice: "Board deleted" }
      format.json { head :no_content }
    end
  end
end
```

### Pattern 2: Jbuilder Templates

```ruby
# app/views/boards/index.json.jbuilder
json.array! @boards do |board|
  json.extract! board, :id, :name, :description, :created_at, :updated_at

  json.creator do
    json.id board.creator.id
    json.name board.creator.name
  end

  json.url board_url(board, format: :json)
end

# app/views/boards/show.json.jbuilder
json.extract! @board, :id, :name, :description, :created_at, :updated_at

json.creator do
  json.partial! "users/user", user: @board.creator
end

json.cards @board.cards do |card|
  json.id card.id
  json.title card.title
  json.url board_card_url(@board, card, format: :json)
end

json.url board_url(@board, format: :json)

# app/views/boards/_board.json.jbuilder (partial)
json.extract! board, :id, :name, :description
json.url board_url(board, format: :json)
```

### Pattern 3: Token Authentication

```ruby
# app/models/api_token.rb
class ApiToken < ApplicationRecord
  belongs_to :user
  belongs_to :account

  has_secure_token :token, length: 32

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  def use!
    touch(:last_used_at)
  end

  def deactivate!
    update!(active: false)
  end
end

# app/controllers/concerns/api_authenticatable.rb
module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_from_token, if: :api_request?
  end

  private

  def api_request?
    request.format.json?
  end

  def authenticate_from_token
    token = extract_token_from_header

    if token
      @api_token = ApiToken.active.find_by(token: token)

      if @api_token
        @api_token.use!
        Current.user = @api_token.user
        Current.account = @api_token.account
      else
        render_unauthorized
      end
    else
      render_unauthorized
    end
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    header&.match(/Bearer (.+)/)&.captures&.first
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include ApiAuthenticatable

  skip_before_action :verify_authenticity_token, if: :api_request?
  before_action :authenticate_user!, unless: :api_request?
end
```

### Pattern 4: Error Handling

```ruby
# app/controllers/concerns/api_error_handling.rb
module ApiErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  end

  private

  def render_not_found(exception)
    respond_to do |format|
      format.html { raise exception }
      format.json do
        render json: {
          error: "Not found",
          message: exception.message
        }, status: :not_found
      end
    end
  end

  def render_unprocessable_entity(exception)
    respond_to do |format|
      format.html { raise exception }
      format.json do
        render json: {
          error: "Validation failed",
          details: exception.record.errors.as_json
        }, status: :unprocessable_entity
      end
    end
  end
end
```

### Pattern 5: HTTP Caching

```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards.includes(:creator)

    respond_to do |format|
      format.html
      format.json do
        if stale?(@boards)
          render :index
        end
      end
    end
  end

  def show
    @board = Current.account.boards.find(params[:id])

    respond_to do |format|
      format.html
      format.json do
        if stale?(@board)
          render :show
        end
      end
    end
  end
end
```

### Pattern 6: Pagination

```ruby
# app/controllers/boards_controller.rb
class BoardsController < ApplicationController
  def index
    @boards = Current.account.boards
      .includes(:creator)
      .order(created_at: :desc)
      .page(params[:page])
      .per(params[:per_page] || 25)

    respond_to do |format|
      format.html
      format.json do
        response.headers["X-Total-Count"] = @boards.total_count.to_s
        response.headers["X-Page"] = @boards.current_page.to_s
        response.headers["X-Per-Page"] = @boards.limit_value.to_s
        response.headers["X-Total-Pages"] = @boards.total_pages.to_s

        render :index
      end
    end
  end
end

# app/views/boards/index.json.jbuilder
json.boards @boards do |board|
  json.extract! board, :id, :name
  json.url board_url(board, format: :json)
end

json.pagination do
  json.current_page @boards.current_page
  json.total_pages @boards.total_pages
  json.total_count @boards.total_count

  if @boards.next_page
    json.next_page boards_url(page: @boards.next_page, format: :json)
  end

  if @boards.prev_page
    json.prev_page boards_url(page: @boards.prev_page, format: :json)
  end
end
```

## Commands

```bash
# Generate API token model
rails generate model ApiToken user:references account:references token:string name:string last_used_at:datetime active:boolean

# Test API with curl
curl -H "Authorization: Bearer TOKEN" \
     -H "Accept: application/json" \
     http://localhost:3000/boards

# Test API with httpie (better than curl)
http GET localhost:3000/boards \
  "Authorization: Bearer TOKEN" \
  "Accept: application/json"

# Create API token in console
ApiToken.create!(
  user: user,
  account: account,
  name: "Development Token"
)
```

## Jbuilder Techniques

```ruby
# Extract attributes
json.extract! @board, :id, :name, :description

# Partial rendering
json.creator do
  json.partial! "users/user", user: @board.creator
end

# Arrays with partials
json.cards @board.cards, partial: "cards/card", as: :card

# Conditional attributes
if Current.user.admin?
  json.internal_notes @board.internal_notes
end

# Cache fragments
json.cache! @board do
  json.extract! @board, :id, :name
end

# Cache collection
json.boards do
  json.array! @boards, cache: true do |board|
    json.extract! board, :id, :name
  end
end
```

## Testing

```ruby
# test/controllers/boards_controller_test.rb
require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @token = api_tokens(:alice_token)
  end

  test "index returns JSON" do
    get account_boards_path(@account),
        headers: api_headers(@token),
        as: :json

    assert_response :success

    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end

  test "create returns JSON" do
    assert_difference "Board.count" do
      post account_boards_path(@account),
           params: { board: { name: "New Board" } },
           headers: api_headers(@token),
           as: :json
    end

    assert_response :created
  end

  test "requires authentication" do
    get account_boards_path(@account), as: :json

    assert_response :unauthorized
  end

  test "returns 304 when not modified" do
    board = boards(:design)

    get account_board_path(@account, board),
        headers: api_headers(@token),
        as: :json

    etag = response.headers["ETag"]

    get account_board_path(@account, board),
        headers: api_headers(@token).merge("If-None-Match" => etag),
        as: :json

    assert_response :not_modified
  end

  private

  def api_headers(token)
    { "Authorization" => "Bearer #{token.token}" }
  end
end
```

## Boundaries

### Always:
- Use same controllers for HTML and JSON (respond_to blocks)
- Use Jbuilder for JSON views (not inline JSON)
- Return proper HTTP status codes
- Implement token-based authentication for API
- Use RESTful routes
- Include resource URLs in JSON responses
- Scope API requests to Current.account
- Use ETags for HTTP caching
- Test both HTML and JSON responses

### Ask First:
- Whether to version API initially
- Pagination strategy (page-based vs cursor-based)
- Whether to support batch operations
- Rate limiting requirements
- Custom non-RESTful endpoints

### Never:
- Use GraphQL (stick to REST)
- Create separate API controllers
- Use Active Model Serializers
- Inline JSON in controllers
- Skip authentication for API endpoints
- Return HTML errors for JSON requests
- Use session-based auth for API
