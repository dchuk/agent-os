---
name: writing-policies
description: Writes Pundit authorization policies for Rails applications following the principle of least privilege with comprehensive tests (OPTIONAL skill - use when authorization is needed)
---

You are an expert in authorization with Pundit for Rails applications.

**NOTE:** This is an OPTIONAL skill. Only use it when the project explicitly requires authorization or when dealing with security-sensitive actions. Many projects may not need Pundit policies.

## Quick Start

**What you build:** Clear, secure, and well-tested Pundit policies that control who can do what with which resources.

**When to use this skill:**
- Project uses Pundit for authorization (check for `app/policies/` directory)
- Creating policies for new resources
- Implementing role-based or ownership-based permissions

**When NOT to use this skill:**
- Project doesn't use Pundit
- Simple public-only applications
- Before confirming authorization requirements

## Core Principles

### 1. Deny by Default

All permissions default to `false` - explicitly grant access.

```ruby
class EntityPolicy < ApplicationPolicy
  def index?
    true  # Explicitly allow
  end

  def create?
    user.present?  # Only authenticated users
  end

  def update?
    user.present? && owner?  # Only owners
  end

  private

  def owner?
    record.user_id == user.id
  end
end
```

### 2. Test Every Permission

Every policy method must have tests covering all roles.

```ruby
RSpec.describe EntityPolicy, type: :policy do
  subject(:policy) { described_class.new(user, entity) }

  context "unauthenticated visitor" do
    let(:user) { nil }
    it { is_expected.to forbid_action(:create) }
  end

  context "entity owner" do
    let(:user) { owner }
    it { is_expected.to permit_action(:update) }
  end
end
```

### 3. Scope Data Appropriately

Use `policy_scope` to filter collections.

```ruby
class EntityPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.published
      end
    end
  end
end
```

## Common Patterns

### ApplicationPolicy Base Class

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
```

### Basic CRUD Policy

```ruby
class EntityPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present?
  end

  def update?
    user.present? && owner?
  end

  def destroy?
    user.present? && owner?
  end

  def permitted_attributes
    owner? ? [:name, :description, :address] : []
  end

  class Scope < Scope
    def resolve
      scope.published
    end
  end

  private

  def owner?
    record.user_id == user.id
  end
end
```

### Policy with Roles

```ruby
class SubmissionPolicy < ApplicationPolicy
  def update?
    return false unless user.present?
    author? || admin?
  end

  def destroy?
    return false unless user.present?
    author? || admin? || entity_owner?
  end

  # Custom actions
  def moderate?
    user.present? && (admin? || entity_owner?)
  end

  def approve?
    admin?
  end

  class Scope < Scope
    def resolve
      user&.admin? ? scope.all : scope.approved
    end
  end

  private

  def author?
    record.user_id == user.id
  end

  def admin?
    user.admin?
  end

  def entity_owner?
    record.entity.user_id == user.id
  end
end
```

### Policy with Temporal Conditions

```ruby
class BookingPolicy < ApplicationPolicy
  def cancel?
    return false unless user.present?
    return false if in_past?

    (owner? && can_still_cancel?) || entity_owner? || admin?
  end

  def update?
    return false unless user.present?
    return false if in_past?

    owner? && can_still_modify?
  end

  private

  def owner?
    record.user_id == user.id
  end

  def in_past?
    record.booking_date < Date.current
  end

  def can_still_modify?
    record.booking_datetime > 2.hours.from_now
  end

  def can_still_cancel?
    record.booking_datetime > 4.hours.from_now
  end
end
```

## Usage in Controllers

### Standard Authorization

```ruby
class EntitiesController < ApplicationController
  before_action :set_entity, only: [:show, :edit, :update, :destroy]

  def index
    @entities = policy_scope(Entity)
  end

  def show
    authorize @entity
  end

  def create
    @entity = current_user.entities.build(entity_params)
    authorize @entity

    if @entity.save
      redirect_to @entity
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @entity
    @entity.update(permitted_attributes(@entity))
    redirect_to @entity
  end

  private

  def entity_params
    params.require(:entity).permit(policy(@entity || Entity).permitted_attributes)
  end
end
```

### Error Handling

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
```

### Custom Actions

```ruby
def moderate
  @submission = Submission.find(params[:id])
  authorize @submission, :moderate?
  @submission.update(status: params[:status])
  redirect_to @submission.entity
end
```

## Usage in Views

```erb
<% if policy(@entity).update? %>
  <%= link_to "Edit", edit_entity_path(@entity) %>
<% end %>

<% if policy(@entity).destroy? %>
  <%= button_to "Delete", entity_path(@entity), method: :delete %>
<% end %>

<% if policy(Submission).create? %>
  <%= link_to "Submit", new_entity_submission_path(@entity) %>
<% end %>
```

## RSpec Tests

### Setup Pundit Matchers

```ruby
# spec/support/pundit_matchers.rb
require "pundit/rspec"

RSpec.configure do |config|
  config.include Pundit::RSpec::Matchers, type: :policy
end
```

### Policy Spec

```ruby
# spec/policies/entity_policy_spec.rb
require "rails_helper"

RSpec.describe EntityPolicy, type: :policy do
  subject(:policy) { described_class.new(user, entity) }

  let(:entity) { create(:entity, user: owner) }
  let(:owner) { create(:user) }

  context "unauthenticated visitor" do
    let(:user) { nil }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_action(:create) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context "authenticated user (non-owner)" do
    let(:user) { create(:user) }

    it { is_expected.to permit_action(:create) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context "entity owner" do
    let(:user) { owner }

    it { is_expected.to permit_actions(:index, :show, :create, :update, :destroy) }
  end

  describe "Scope" do
    subject(:scope) { described_class::Scope.new(user, Entity.all).resolve }

    let!(:published_entity) { create(:entity, published: true) }
    let!(:unpublished_entity) { create(:entity, published: false) }

    it "returns only published entities" do
      expect(scope).to include(published_entity)
      expect(scope).not_to include(unpublished_entity)
    end
  end

  describe "#permitted_attributes" do
    context "owner" do
      let(:user) { owner }

      it "allows attributes" do
        expect(policy.permitted_attributes).to include(:name, :description)
      end
    end

    context "non-owner" do
      let(:user) { create(:user) }

      it "allows no attributes" do
        expect(policy.permitted_attributes).to be_empty
      end
    end
  end
end
```

## Commands

### Tests

- **All policies:** `bundle exec rspec spec/policies/`
- **Specific policy:** `bundle exec rspec spec/policies/entity_policy_spec.rb`
- **Specific line:** `bundle exec rspec spec/policies/entity_policy_spec.rb:25`

### Generation

- **Generate policy:** `bin/rails generate pundit:policy Entity`

### Linting

- **Lint policies:** `bundle exec rubocop -a app/policies/`
- **Lint specs:** `bundle exec rubocop -a spec/policies/`

### Audit

- **Search for missing authorize:** `grep -r "def " app/controllers/ | grep -v "authorize"`

## Security Checklist

- [ ] Each controller action has `authorize` or `policy_scope`
- [ ] Policies follow deny-by-default
- [ ] Tests cover all roles and edge cases
- [ ] `Scope` properly filters data
- [ ] `permitted_attributes` defined for updates

### Required Test Scenarios

- [ ] Unauthenticated visitor (`user: nil`)
- [ ] Regular authenticated user
- [ ] Resource owner/author
- [ ] Admin (if applicable)
- [ ] Custom actions

## Boundaries

### Always Do

- Write policy specs for every policy
- Follow deny-by-default principle
- Use `policy_scope` for filtering collections
- Verify every controller action has authorization
- Test all roles and edge cases

### Ask First

- Before granting admin-level permissions
- Before modifying existing policies affecting many users
- Before adding complex authorization logic

### Never Do

- Skip authorization checks in controllers
- Allow everything by default
- Skip policy tests
- Hardcode user IDs or roles
- Forget to handle `user: nil` case
