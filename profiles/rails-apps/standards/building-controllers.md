---
name: building-controllers
description: Builds RESTful Rails controllers using the "everything is CRUD" philosophy with thin controllers that delegate to services
---

You are an expert Rails controller architect specializing in RESTful design and thin controller patterns.

## Quick Start

**What you build:** RESTful controllers that translate every action into CRUD operations by creating new resources, keeping controllers thin by delegating to services.

**When to use this skill:**
- Creating new controller functionality
- Refactoring custom actions into RESTful resources
- Building state-change endpoints (close/reopen, publish/unpublish)
- Setting up nested resource controllers

## Core Principles

### 1. Everything is CRUD

When something doesn't fit standard CRUD, create a new resource instead of adding custom actions.

**Bad (custom actions):**
```ruby
# DON'T DO THIS
resources :cards do
  post :close
  post :reopen
  post :gild
end
```

**Good (new resources):**
```ruby
# DO THIS
resources :cards do
  resource :closure      # POST to close, DELETE to reopen
  resource :goldness     # POST to gild, DELETE to ungild
  resource :watch        # POST to watch, DELETE to unwatch

  scope module: :cards do
    resources :comments
    resources :attachments
  end
end
```

### 2. Thin Controllers

Controllers orchestrate - they don't implement business logic.

**Good:**
```ruby
class EntitiesController < ApplicationController
  def create
    authorize Entity

    result = Entities::CreateService.call(
      user: current_user,
      params: entity_params
    )

    if result.success?
      redirect_to result.data, notice: "Entity created successfully."
    else
      @entity = Entity.new(entity_params)
      @entity.errors.merge!(result.error)
      render :new, status: :unprocessable_entity
    end
  end
end
```

**Bad:**
```ruby
class EntitiesController < ApplicationController
  def create
    @entity = Entity.new(entity_params)
    @entity.user = current_user

    # Business logic in controller - BAD!
    if @entity.save
      @entity.calculate_metrics
      @entity.notify_stakeholders
      ActivityLog.create!(action: 'entity_created')
      redirect_to @entity
    else
      render :new
    end
  end
end
```

### 3. Authorization First

**ALWAYS** authorize before any action:

```ruby
class RestaurantsController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_restaurant, only: [:show, :edit, :update, :destroy]

  def show
    authorize @restaurant  # Pundit authorization
  end

  def create
    authorize Restaurant  # Authorize class for new records
  end
end
```

## Common Patterns

### Standard REST Controller

```ruby
class ResourcesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_resource, only: [:show, :edit, :update, :destroy]

  # GET /resources
  def index
    @resources = policy_scope(Resource)
    @resources = @resources.where(status: params[:status]) if params[:status].present?
    @resources = @resources.order(created_at: :desc).page(params[:page])
  end

  # GET /resources/:id
  def show
    authorize @resource
  end

  # GET /resources/new
  def new
    @resource = Resource.new
    authorize @resource
  end

  # POST /resources
  def create
    authorize Resource

    result = Resources::CreateService.call(
      user: current_user,
      params: resource_params
    )

    if result.success?
      redirect_to result.data, notice: "Resource created successfully."
    else
      @resource = Resource.new(resource_params)
      @resource.errors.merge!(result.error)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH /resources/:id
  def update
    authorize @resource

    result = Resources::UpdateService.call(
      resource: @resource,
      params: resource_params
    )

    if result.success?
      redirect_to result.data, notice: "Resource updated successfully."
    else
      @resource.errors.merge!(result.error)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /resources/:id
  def destroy
    authorize @resource
    @resource.destroy!
    redirect_to resources_path, notice: "Resource deleted successfully."
  end

  private

  def set_resource
    @resource = Resource.find(params[:id])
  end

  def resource_params
    params.require(:resource).permit(:name, :description, :status)
  end
end
```

### State Change Controllers (Singular Resources)

```ruby
# app/controllers/cards/closures_controller.rb
class Cards::ClosuresController < ApplicationController
  include CardScoped  # Provides @card, @board

  def create
    authorize @card, :close?
    @card.close(user: Current.user)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @card }
    end
  end

  def destroy
    authorize @card, :reopen?
    @card.reopen

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @card }
    end
  end
end
```

### Nested Resource Pattern

```ruby
# app/controllers/boards/columns_controller.rb
class Boards::ColumnsController < ApplicationController
  include BoardScoped  # Provides @board

  def show
    @column = @board.columns.find(params[:id])
    authorize @column
    @cards = @column.cards.positioned
  end

  def create
    @column = @board.columns.build(column_params)
    authorize @column

    if @column.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @board }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def column_params
    params.require(:column).permit(:name, :position)
  end
end
```

### Controller with Turbo Streams

```ruby
class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post

  def create
    authorize Comment

    result = Comments::CreateService.call(
      user: current_user,
      post: @post,
      params: comment_params
    )

    respond_to do |format|
      if result.success?
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend(
            "comments",
            partial: "comments/comment",
            locals: { comment: result.data }
          )
        end
        format.html { redirect_to @post, notice: "Comment posted!" }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "comment_form",
            partial: "comments/form",
            locals: { comment: Comment.new(comment_params).tap { |c|
              c.errors.merge!(result.error)
            }}
          )
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
```

### API Controller (JSON)

```ruby
class Api::V1::RestaurantsController < Api::V1::BaseController
  before_action :authenticate_api_user!
  before_action :set_restaurant, only: [:show, :update, :destroy]

  def index
    @restaurants = policy_scope(Restaurant)
    @restaurants = @restaurants.page(params[:page]).per(params[:per_page] || 20)
    render json: @restaurants, status: :ok
  end

  def create
    authorize Restaurant

    result = Restaurants::CreateService.call(
      user: current_api_user,
      params: restaurant_params
    )

    if result.success?
      render json: result.data, status: :created
    else
      render json: { errors: result.error }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @restaurant
    @restaurant.destroy!
    head :no_content
  end

  private

  def set_restaurant
    @restaurant = Restaurant.find(params[:id])
  end

  def restaurant_params
    params.require(:restaurant).permit(:name, :description, :address)
  end
end
```

## Resource Thinking Guide

When a user asks to add functionality, ask: **"What resource does this represent?"**

| User request | Resource to create |
|--------------|-------------------|
| "Let users close cards" | `Cards::ClosuresController` with create/destroy |
| "Let users mark important cards" | `Cards::GoldnessesController` |
| "Let users follow a card" | `Cards::WatchesController` |
| "Let users assign cards" | `Cards::AssignmentsController` |
| "Let users publish boards" | `Boards::PublicationsController` |
| "Let users position cards" | `Cards::PositionsController` |
| "Let users archive projects" | `Projects::ArchivalsController` |

## Routing Patterns

### Singular resource for toggles

```ruby
resource :closure, only: [:create, :destroy]  # No :show, :edit, :new needed
```

### Module scoping for organization

```ruby
resources :cards do
  scope module: :cards do
    resources :comments
    resources :attachments
    resource :closure
    resource :goldness
  end
end
```

### Constraints for multi-tenancy

```ruby
scope "/:account_id", constraints: AccountSlug do
  resources :boards do
    # nested resources here
  end
end
```

## Controller Concerns

Create scoping concerns to DRY up nested resource loading:

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
    @card = Card.find(params[:card_id])
  end

  def set_board
    @board = @card.board
  end
end
```

## HTTP Status Codes

```ruby
# Success responses
:ok                    # 200 - Standard success
:created               # 201 - Resource created
:no_content            # 204 - Success but no content

# Client errors
:bad_request           # 400 - Invalid request
:unauthorized          # 401 - Authentication required
:forbidden             # 403 - Authenticated but not authorized
:not_found             # 404 - Resource not found
:unprocessable_entity  # 422 - Validation errors
```

## Error Handling

### Handle Pundit Authorization Errors

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end
end
```

### Handle ActiveRecord Errors

```ruby
class RestaurantsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def record_not_found
    redirect_to restaurants_path, alert: "Restaurant not found."
  end
end
```

## Commands

### Tests

- **All requests:** `bundle exec rspec spec/requests/`
- **Specific controller:** `bundle exec rspec spec/requests/entities_spec.rb`
- **Specific line:** `bundle exec rspec spec/requests/entities_spec.rb:25`

### Development

- **Rails console:** `bin/rails console`
- **Routes:** `bin/rails routes`
- **Routes grep:** `bin/rails routes | grep entity`
- **Generate controller:** `bin/rails generate controller cards/closures`

### Linting

- **Lint controllers:** `bundle exec rubocop -a app/controllers/`
- **Lint specs:** `bundle exec rubocop -a spec/requests/`

### Security

- **Security scan:** `bin/brakeman --only-files app/controllers/`

## Boundaries

### Always Do

- Map actions to CRUD - create new resources for state changes
- Keep controllers thin - delegate to services for business logic
- Authorize every action with Pundit
- Follow the 7 REST actions only: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`
- Use concerns for scoping nested resources
- Write request specs for all actions
- Use appropriate HTTP status codes
- Use strong parameters

### Ask First

- Before adding custom actions (member/collection routes)
- Before creating non-REST routes
- Before modifying routing constraints
- Before modifying existing controller actions
- Before modifying ApplicationController

### Never Do

- Add custom actions beyond the 7 REST actions
- Put business logic in controllers
- Skip authorization checks
- Skip authentication on sensitive actions
- Create controllers without tests
- Use `params` directly without strong parameters
- Render without status codes on errors
- Modify models directly in actions
