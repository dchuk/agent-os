---
name: writing-services
description: Creates Service Objects for complex multi-step business logic using the Result pattern
---

# Writing Services Skill

Expert in Service Object design for Rails applications following SOLID principles.

## Quick Start

Service Objects encapsulate complex business logic into focused, testable classes. Use them when:
- Logic involves multiple models
- Actions require transactions
- There are side effects (emails, notifications, external APIs)
- Logic is too complex for a model
- You need to reuse logic across controllers, jobs, and console

**Basic Usage:**
```ruby
result = Entities::CreateService.call(user: current_user, params: entity_params)

if result.success?
  redirect_to result.data, notice: "Entity created successfully"
else
  flash[:alert] = result.error
  render :new, status: :unprocessable_entity
end
```

## Core Principles

### 1. Single Responsibility Principle (SRP)
Each service should do ONE thing well. If your service has multiple responsibilities, split it.

### 2. Result Objects
Always use Result objects to communicate success/failure:
```ruby
Result = Data.define(:success, :data, :error) do
  def success? = success
  def failure? = !success
end

# Return with:
success(data)    # Success with data
failure(error)   # Failure with error message
```

### 3. Naming Convention
Services are organized by domain and action:
```
app/services/
├── application_service.rb          # Base class
├── entities/
│   ├── create_service.rb           # Entities::CreateService
│   ├── update_service.rb           # Entities::UpdateService
│   └── calculate_rating_service.rb # Entities::CalculateRatingService
└── submissions/
    ├── create_service.rb           # Submissions::CreateService
    └── moderate_service.rb         # Submissions::ModerateService
```

### 4. Always Test
Every service MUST have a corresponding RSpec test in `spec/services/`.

## Patterns

### ApplicationService Base Class

```ruby
# app/services/application_service.rb
class ApplicationService
  def self.call(...)
    new(...).call
  end

  private

  def success(data = nil)
    Result.new(success: true, data: data, error: nil)
  end

  def failure(error)
    Result.new(success: false, data: nil, error: error)
  end

  Result = Data.define(:success, :data, :error) do
    def success? = success
    def failure? = !success
  end
end
```

### Pattern 1: Simple CRUD Service

```ruby
# app/services/entities/create_service.rb
module Entities
  class CreateService < ApplicationService
    def initialize(user:, params:)
      @user = user
      @params = params
    end

    def call
      return failure("User not authorized") unless authorized?

      entity = build_entity

      if entity.save
        notify_owner
        success(entity)
      else
        failure(entity.errors.full_messages.join(", "))
      end
    end

    private

    attr_reader :user, :params

    def authorized?
      user.present?
    end

    def build_entity
      user.entities.build(permitted_params)
    end

    def permitted_params
      params.slice(:name, :description, :address, :phone)
    end

    def notify_owner
      EntityMailer.created(entity).deliver_later
    end
  end
end
```

**RSpec Test:**
```ruby
# spec/services/entities/create_service_spec.rb
require "rails_helper"

RSpec.describe Entities::CreateService do
  describe ".call" do
    subject(:result) { described_class.call(user: user, params: params) }

    let(:user) { create(:user) }
    let(:params) { attributes_for(:entity) }

    context "with valid parameters" do
      it "creates an entity" do
        expect { result }.to change(Entity, :count).by(1)
      end

      it "returns success" do
        expect(result).to be_success
      end

      it "returns the created entity" do
        expect(result.data).to be_a(Entity)
        expect(result.data).to be_persisted
      end
    end

    context "with invalid parameters" do
      let(:params) { { name: "" } }

      it "does not create an entity" do
        expect { result }.not_to change(Entity, :count)
      end

      it "returns failure" do
        expect(result).to be_failure
      end

      it "returns an error message" do
        expect(result.error).to include("Name")
      end
    end

    context "without user" do
      let(:user) { nil }

      it "returns failure with authorization error" do
        expect(result).to be_failure
        expect(result.error).to eq("User not authorized")
      end
    end
  end
end
```

### Pattern 2: Service with Transaction

Use transactions when multiple database operations must succeed together or all fail.

```ruby
# app/services/orders/create_service.rb
module Orders
  class CreateService < ApplicationService
    def initialize(user:, cart:)
      @user = user
      @cart = cart
    end

    def call
      return failure("Cart is empty") if cart.empty?

      order = nil

      ActiveRecord::Base.transaction do
        order = create_order
        create_order_items(order)
        clear_cart
        charge_payment(order)
      end

      success(order)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.message)
    rescue PaymentError => e
      failure("Payment error: #{e.message}")
    end

    private

    attr_reader :user, :cart

    def create_order
      user.orders.create!(total: cart.total, status: :pending)
    end

    def create_order_items(order)
      cart.items.each do |item|
        order.order_items.create!(
          product: item.product,
          quantity: item.quantity,
          price: item.price
        )
      end
    end

    def clear_cart
      cart.clear!
    end

    def charge_payment(order)
      PaymentGateway.charge(user: user, amount: order.total)
      order.update!(status: :paid)
    end
  end
end
```

**Testing Transactions:**
```ruby
# spec/services/orders/create_service_spec.rb
RSpec.describe Orders::CreateService do
  describe ".call" do
    subject(:result) { described_class.call(user: user, cart: cart) }

    let(:user) { create(:user) }
    let(:cart) { create(:cart, :with_items, user: user) }

    context "when payment fails" do
      before do
        allow(PaymentGateway).to receive(:charge).and_raise(PaymentError, "Card declined")
      end

      it "does not create order (rollback)" do
        expect { result }.not_to change(Order, :count)
      end

      it "does not clear cart (rollback)" do
        expect { result }.not_to change { cart.reload.items.count }
      end

      it "returns failure" do
        expect(result).to be_failure
        expect(result.error).to include("Card declined")
      end
    end
  end
end
```

### Pattern 3: Calculation/Update Service

```ruby
# app/services/entities/calculate_rating_service.rb
module Entities
  class CalculateRatingService < ApplicationService
    def initialize(entity:)
      @entity = entity
    end

    def call
      average = calculate_average_rating

      if entity.update(average_rating: average, submissions_count: submissions_count)
        success(average)
      else
        failure(entity.errors.full_messages.join(", "))
      end
    end

    private

    attr_reader :entity

    def calculate_average_rating
      return 0.0 if submissions_count.zero?

      entity.submissions.average(:rating).to_f.round(1)
    end

    def submissions_count
      @submissions_count ||= entity.submissions.count
    end
  end
end
```

### Pattern 4: Service with Injected Dependencies

For testability, inject dependencies rather than hardcoding them.

```ruby
# app/services/notifications/send_service.rb
module Notifications
  class SendService < ApplicationService
    def initialize(user:, message:, notifier: default_notifier)
      @user = user
      @message = message
      @notifier = notifier
    end

    def call
      return failure("User has notifications disabled") unless user.notifications_enabled?

      notifier.deliver(user: user, message: message)
      success
    rescue NotificationError => e
      failure(e.message)
    end

    private

    attr_reader :user, :message, :notifier

    def default_notifier
      Rails.env.test? ? NullNotifier.new : PushNotifier.new
    end
  end
end
```

### Pattern 5: Service Composition

Services can call other services for complex workflows:

```ruby
# app/services/submissions/create_service.rb
module Submissions
  class CreateService < ApplicationService
    def initialize(user:, entity:, params:)
      @user = user
      @entity = entity
      @params = params
    end

    def call
      return failure("You have already submitted") if already_submitted?

      submission = build_submission

      if submission.save
        update_entity_rating
        success(submission)
      else
        failure(submission.errors.full_messages.join(", "))
      end
    end

    private

    attr_reader :user, :entity, :params

    def already_submitted?
      entity.submissions.exists?(user: user)
    end

    def build_submission
      entity.submissions.build(params.merge(user: user))
    end

    def update_entity_rating
      # Calling another service
      Entities::CalculateRatingService.call(entity: entity)
    end
  end
end
```

**Testing Service Composition:**
```ruby
# spec/services/submissions/create_service_spec.rb
RSpec.describe Submissions::CreateService do
  describe ".call" do
    subject(:result) { described_class.call(user: user, entity: entity, params: params) }

    let(:user) { create(:user) }
    let(:entity) { create(:entity) }
    let(:params) { { rating: 4, content: "Excellent!" } }

    it "updates the entity rating" do
      expect(Entities::CalculateRatingService)
        .to receive(:call)
        .with(entity: entity)

      result
    end

    context "when user has already submitted" do
      before { create(:submission, user: user, entity: entity) }

      it "returns failure" do
        expect(result).to be_failure
        expect(result.error).to eq("You have already submitted")
      end
    end
  end
end
```

## Commands

### Testing Services

```bash
# Run all service tests
bundle exec rspec spec/services/

# Run specific service test
bundle exec rspec spec/services/entities/create_service_spec.rb

# Run specific test case (line number)
bundle exec rspec spec/services/entities/create_service_spec.rb:25

# Run with detailed output
bundle exec rspec --format documentation spec/services/
```

### Linting Services

```bash
# Auto-fix service code
bundle exec rubocop -a app/services/

# Auto-fix service specs
bundle exec rubocop -a spec/services/
```

### Manual Testing

```bash
# Open Rails console
bin/rails console

# Test service manually
result = Entities::CreateService.call(
  user: User.first,
  params: { name: "Test Entity", description: "Test" }
)

result.success?  # => true or false
result.data      # => Entity object or nil
result.error     # => nil or error message
```

## Boundaries

### Always Do:
- Write RSpec tests for every service
- Use Result objects for return values
- Follow the Single Responsibility Principle
- Handle errors explicitly
- Use transactions when needed
- Return meaningful error messages
- Use attr_reader for instance variables

### Ask First Before:
- Modifying existing services used by multiple controllers
- Adding external API calls
- Creating services that modify global state
- Adding complex dependencies

### Never Do:
- Skip writing tests
- Put service logic in controllers or models
- Ignore error handling
- Create services without tests
- Silently swallow errors
- Create "God services" that do everything
- Put presentation logic in services
- Use services for simple CRUD without business logic

## When to Use Service Objects

### Use Services When:
- Logic involves multiple models
- Action requires a database transaction
- There are side effects (emails, notifications, external APIs)
- Logic is too complex for a model
- You need to reuse logic (controller, job, console)
- Business logic needs to be tested independently

### Don't Use Services When:
- It's simple CRUD without business logic
- Logic clearly belongs in the model (single model concern)
- You're creating a "wrapper" service without added value
- A simple scope or model method would suffice

## Controller Integration

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  def create
    result = Entities::CreateService.call(
      user: current_user,
      params: entity_params
    )

    if result.success?
      redirect_to result.data, notice: "Entity created successfully"
    else
      @entity = Entity.new(entity_params)
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end

  private

  def entity_params
    params.require(:entity).permit(:name, :description, :address, :phone)
  end
end
```

## Tech Stack

- **Ruby:** 3.3
- **Rails:** 8.1
- **Testing:** RSpec, FactoryBot
- **Pattern:** Command Pattern with Result Objects
