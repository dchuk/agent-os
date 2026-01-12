---
name: building-forms
description: Builds Form Objects for Rails applications that handle multi-model forms, complex validations, and virtual attributes
---

You are an expert in Form Objects for Rails applications.

## Quick Start

**What you build:** Form Objects that wrap multiple models, handle complex validations, and manage virtual attributes for forms that don't map cleanly to a single model.

**When to use this skill:**
- Creating/modifying multiple models at once
- Forms with virtual attributes that aren't persisted
- Complex cross-model validations
- Reusable form logic

**When NOT to use this skill:**
- Simple CRUD on a single model
- When `accepts_nested_attributes_for` is sufficient

## Core Principles

### 1. Multi-Model Coordination

Form Objects coordinate operations across multiple models in a single transaction.

```ruby
class EntityRegistrationForm < ApplicationForm
  attribute :name, :string              # Entity
  attribute :phone, :string             # ContactInfo
  attribute :email, :string             # ContactInfo

  private

  def persist!
    ActiveRecord::Base.transaction do
      @entity = create_entity
      create_contact_info
      notify_owner
    end
  end
end
```

### 2. Validation Before Persistence

All validations run before any database writes occur.

```ruby
class ContentSubmissionForm < ApplicationForm
  validates :content, presence: true, length: { minimum: 20, maximum: 1000 }
  validate :author_hasnt_submitted_already

  def save
    return false unless valid?  # Validates FIRST
    persist!  # Only writes if valid
    true
  end
end
```

### 3. Transactional Integrity

All database writes happen in a transaction - if any part fails, everything rolls back.

```ruby
def persist!
  ActiveRecord::Base.transaction do
    @entity = create_entity
    create_items              # If this fails...
    update_entity_rating      # ...this never happens
  end
end
```

## Common Patterns

### ApplicationForm Base Class

```ruby
# app/forms/application_form.rb
class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  def save
    return false unless valid?

    persist!
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  private

  def persist!
    raise NotImplementedError, "Subclasses must implement #persist!"
  end
end
```

### Simple Multi-Model Form

```ruby
# app/forms/entity_registration_form.rb
class EntityRegistrationForm < ApplicationForm
  attribute :name, :string
  attribute :description, :text
  attribute :address, :string
  attribute :phone, :string
  attribute :email, :string
  attribute :owner_id, :integer

  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :owner_exists

  attr_reader :entity

  private

  def persist!
    ActiveRecord::Base.transaction do
      @entity = create_entity
      create_contact_info
      notify_owner
    end
  end

  def create_entity
    Entity.create!(
      owner_id: owner_id,
      name: name,
      description: description,
      address: address
    )
  end

  def create_contact_info
    entity.create_contact_info!(phone: phone, email: email)
  end

  def notify_owner
    EntityMailer.registration_confirmation(entity).deliver_later
  end

  def owner_exists
    errors.add(:owner_id, "does not exist") unless User.exists?(owner_id)
  end
end
```

### Form with Nested Associations

```ruby
# app/forms/entity_with_items_form.rb
class EntityWithItemsForm < ApplicationForm
  attribute :name, :string
  attribute :description, :text
  attribute :owner_id, :integer
  attribute :items, default: -> { [] }

  validates :name, presence: true
  validate :validate_items

  attr_reader :entity

  private

  def persist!
    ActiveRecord::Base.transaction do
      @entity = create_entity
      create_items
    end
  end

  def create_items
    items.each do |item_attrs|
      next if item_attrs[:name].blank?

      entity.items.create!(
        name: item_attrs[:name],
        price: item_attrs[:price],
        category: item_attrs[:category]
      )
    end
  end

  def validate_items
    return if items.blank?

    items.each_with_index do |item, index|
      next if item[:name].blank?

      if item[:price].to_f <= 0
        errors.add(:base, "Item #{index + 1} price must be positive")
      end
    end
  end
end
```

### Form with Virtual Attributes

```ruby
# app/forms/content_submission_form.rb
class ContentSubmissionForm < ApplicationForm
  attribute :entity_id, :integer
  attribute :author_id, :integer
  attribute :content, :text

  # Virtual attributes for sub-criteria
  attribute :quality_score, :integer
  attribute :accuracy_score, :integer
  attribute :relevance_score, :integer

  validates :content, presence: true, length: { minimum: 20 }
  validates :quality_score, :accuracy_score, :relevance_score,
            inclusion: { in: 1..5 }

  attr_reader :submission

  private

  def persist!
    ActiveRecord::Base.transaction do
      @submission = create_submission
      create_scores
      update_entity_rating
    end
  end

  def create_submission
    Submission.create!(
      entity_id: entity_id,
      author_id: author_id,
      rating: calculated_overall_rating,
      content: content
    )
  end

  def create_scores
    submission.create_score!(
      quality: quality_score,
      accuracy: accuracy_score,
      relevance: relevance_score
    )
  end

  def calculated_overall_rating
    # Weighted average of sub-criteria
    ((quality_score * 0.4) + (accuracy_score * 0.3) + (relevance_score * 0.3)).round
  end
end
```

### Edit Form with Pre-Population

```ruby
# app/forms/user_profile_form.rb
class UserProfileForm < ApplicationForm
  attribute :user_id, :integer
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :email, :string
  attribute :bio, :text
  attribute :avatar

  validates :first_name, :last_name, :email, presence: true
  validate :email_uniqueness

  attr_reader :user

  def initialize(attributes = {})
    @user = User.find_by(id: attributes[:user_id])
    super(attributes.merge(user_attributes))
  end

  private

  def persist!
    user.update!(
      first_name: first_name,
      last_name: last_name,
      email: email,
      bio: bio
    )

    user.avatar.attach(avatar) if avatar.present?
  end

  def user_attributes
    return {} unless user

    {
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      bio: user.bio
    }
  end

  def email_uniqueness
    existing = User.where(email: email).where.not(id: user_id).exists?
    errors.add(:email, "is already taken") if existing
  end
end
```

## Usage in Controllers

```ruby
# app/controllers/entities_controller.rb
class EntitiesController < ApplicationController
  def new
    @form = EntityRegistrationForm.new(owner_id: current_user.id)
  end

  def create
    @form = EntityRegistrationForm.new(registration_params)

    if @form.save
      redirect_to @form.entity, notice: "Entity created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:entity_registration_form).permit(
      :name, :description, :address, :phone, :email, :owner_id
    )
  end
end
```

## Usage in Views

### Classic ERB View

```erb
<%# app/views/entities/new.html.erb %>
<%= form_with model: @form, url: entities_path do |f| %>
  <%= render "shared/error_messages", object: @form %>

  <%= f.hidden_field :owner_id %>

  <div class="field">
    <%= f.label :name %>
    <%= f.text_field :name, class: "input" %>
  </div>

  <div class="field">
    <%= f.label :description %>
    <%= f.text_area :description, class: "textarea" %>
  </div>

  <div class="field">
    <%= f.label :email %>
    <%= f.email_field :email, class: "input" %>
  </div>

  <%= f.submit "Create Entity", class: "button" %>
<% end %>
```

### Nested Form with Stimulus

```erb
<%# app/views/entities/new_with_items.html.erb %>
<%= form_with model: @form, url: entities_path,
              data: { controller: "nested-form" } do |f| %>

  <%= f.text_field :name %>
  <%= f.text_area :description %>

  <div data-nested-form-target="container">
    <h3>Items</h3>

    <template data-nested-form-target="template">
      <div class="item">
        <%= f.fields_for :items, OpenStruct.new do |item_f| %>
          <%= item_f.text_field :name, placeholder: "Item name" %>
          <%= item_f.number_field :price, step: 0.01 %>
          <button type="button" data-action="nested-form#remove">Remove</button>
        <% end %>
      </div>
    </template>
  </div>

  <button type="button" data-action="nested-form#add">Add Item</button>
  <%= f.submit "Create" %>
<% end %>
```

## RSpec Tests

### Basic Test

```ruby
# spec/forms/entity_registration_form_spec.rb
require "rails_helper"

RSpec.describe EntityRegistrationForm do
  describe "#save" do
    subject(:form) { described_class.new(attributes) }

    let(:owner) { create(:user) }
    let(:attributes) do
      {
        name: "Test Entity",
        description: "An excellent test entity",
        address: "123 Main Street",
        phone: "1234567890",
        email: "contact@example.com",
        owner_id: owner.id
      }
    end

    context "with valid attributes" do
      it "is valid" do
        expect(form).to be_valid
      end

      it "creates an entity" do
        expect { form.save }.to change(Entity, :count).by(1)
      end

      it "creates contact information" do
        form.save
        expect(form.entity.contact_info).to be_present
        expect(form.entity.contact_info.email).to eq("contact@example.com")
      end

      it "returns true" do
        expect(form.save).to be true
      end
    end

    context "with missing name" do
      let(:attributes) { super().merge(name: "") }

      it "is not valid" do
        expect(form).not_to be_valid
      end

      it "does not create an entity" do
        expect { form.save }.not_to change(Entity, :count)
      end

      it "adds an error to name" do
        form.valid?
        expect(form.errors[:name]).to include("can't be blank")
      end
    end
  end
end
```

### Test with Nested Associations

```ruby
# spec/forms/entity_with_items_form_spec.rb
require "rails_helper"

RSpec.describe EntityWithItemsForm do
  describe "#save" do
    subject(:form) { described_class.new(attributes) }

    let(:owner) { create(:user) }
    let(:attributes) do
      {
        name: "Test Entity",
        description: "Test description",
        owner_id: owner.id,
        items: [
          { name: "Item One", price: "18.50", category: "a" },
          { name: "Item Two", price: "7.00", category: "b" }
        ]
      }
    end

    context "with valid items" do
      it "creates the entity with items" do
        expect { form.save }.to change(Entity, :count).by(1)
                                .and change(Item, :count).by(2)
      end

      it "correctly associates the items" do
        form.save
        expect(form.entity.items.count).to eq(2)
      end
    end

    context "with invalid price" do
      let(:attributes) do
        super().merge(items: [{ name: "Test", price: "-5" }])
      end

      it "is not valid" do
        expect(form).not_to be_valid
        expect(form.errors[:base]).to include(/price.*must be positive/)
      end
    end
  end
end
```

## Commands

### Tests

- **All forms:** `bundle exec rspec spec/forms/`
- **Specific form:** `bundle exec rspec spec/forms/entity_registration_form_spec.rb`
- **Specific line:** `bundle exec rspec spec/forms/entity_registration_form_spec.rb:45`

### Linting

- **Lint forms:** `bundle exec rubocop -a app/forms/`
- **Lint specs:** `bundle exec rubocop -a spec/forms/`

### Console

- **Rails console:** `bin/rails console` (manually test a form)

## Boundaries

### Always Do

- Write form specs for all forms
- Validate all inputs before persistence
- Wrap all persistence in transactions
- Handle errors gracefully
- Return true/false from `#save`
- Expose created records via `attr_reader`

### Ask First

- Before adding database writes to multiple tables
- Before modifying a form used by multiple controllers
- Before adding complex business logic

### Never Do

- Skip validations
- Bypass model validations
- Put business logic in forms (use services)
- Create forms without tests
- Ignore errors from `#persist!`
- Mix presentation logic with form logic
