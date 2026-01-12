---
name: building-components
description: Creates reusable, tested ViewComponents with clear APIs, slots for composition, and Lookbook previews for Rails applications
---

You are a ViewComponent expert, specialized in creating robust, tested, and maintainable View components for Rails.

## Quick Start

**When to use this skill:**
- Creating reusable UI patterns (buttons, cards, alerts, forms)
- Building complex interfaces with slots and composition
- Standardizing design systems across your application
- Testing view logic in isolation
- Documenting components with interactive previews

**Core philosophy:** Create components with single responsibility, clear APIs, and comprehensive tests. Favor composition over inheritance using slots.

## Core Principles

### Rails 8 / Turbo 8 Considerations

- **Morphing:** Turbo 8 uses morphing by default - ensure components have stable DOM IDs
- **View Transitions:** Components work seamlessly with view transitions
- **Streams:** Components integrate well with Turbo Streams

### 1. Clear and Predictable API

Each component must have an intuitive interface with well-named parameters:

```ruby
# ✅ GOOD - Clear API with default values
class ButtonComponent < ViewComponent::Base
  def initialize(
    text:,
    variant: :primary,
    size: :medium,
    disabled: false,
    html_attributes: {}
  )
    @text = text
    @variant = variant
    @size = size
    @disabled = disabled
    @html_attributes = html_attributes
  end
end

# ❌ BAD - Too many parameters without structure
class ButtonComponent < ViewComponent::Base
  def initialize(text, color, bg_color, padding, margin, border, radius, disabled)
    # Too complex and difficult to maintain
  end
end
```

### 2. Single Responsibility Principle

Each component must have a single responsibility:

```ruby
# ✅ GOOD - Focused component
class AlertComponent < ViewComponent::Base
  def initialize(message:, type: :info, dismissible: false)
    @message = message
    @type = type
    @dismissible = dismissible
  end
end

# ❌ BAD - Component that does too much
class NotificationComponent < ViewComponent::Base
  def initialize(message:, send_email: false, log_to_db: false)
    # Component should not handle business logic
    send_email_notification if send_email
    log_to_database if log_to_db
  end
end
```

### 3. Use Slots for Composition

Slots allow creating flexible and composable components:

```ruby
# app/components/card_component.rb
class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
  renders_one :footer
  renders_many :actions, "ActionComponent"

  def initialize(variant: :default, **html_attributes)
    @variant = variant
    @html_attributes = html_attributes
  end

  class ActionComponent < ViewComponent::Base
    def initialize(text:, url:, method: :get, **html_attributes)
      @text = text
      @url = url
      @method = method
      @html_attributes = html_attributes
    end
  end
end
```

```erb
<%# app/components/card_component.html.erb %>
<div class="<%= card_classes %>" <%= html_attributes %>>
  <% if header? %>
    <div class="card-header">
      <%= header %>
    </div>
  <% end %>

  <% if body? %>
    <div class="card-body">
      <%= body %>
    </div>
  <% end %>

  <% if actions? %>
    <div class="card-actions">
      <% actions.each do |action| %>
        <%= action %>
      <% end %>
    </div>
  <% end %>

  <% if footer? %>
    <div class="card-footer">
      <%= footer %>
    </div>
  <% end %>
</div>
```

### 4. Conditional Rendering with #render?

Use `#render?` to control component display:

```ruby
class EmptyStateComponent < ViewComponent::Base
  def initialize(collection:, message: "No items found")
    @collection = collection
    @message = message
  end

  def render?
    @collection.empty?
  end
end
```

### 5. Variants for Multiple Contexts

Use variants to adapt components according to context:

```ruby
class NavigationComponent < ViewComponent::Base
  def initialize(user:)
    @user = user
  end

  # Default template: app/components/navigation_component.html.erb
  # Mobile template: app/components/navigation_component.html+phone.erb
  # Tablet template: app/components/navigation_component.html+tablet.erb
end
```

## Complete Component Structure

### Component with All Elements

```ruby
# app/components/profile_card_component.rb
class ProfileCardComponent < ViewComponent::Base
  # Slots for composition
  renders_one :avatar
  renders_one :badge
  renders_many :actions, ->(text:, url:, **options) do
    link_to text, url, class: action_classes, **options
  end

  # Configuration
  strip_trailing_whitespace

  def initialize(profile:, variant: :default, show_details: false, **html_attributes)
    @profile = profile
    @variant = variant
    @show_details = show_details
    @html_attributes = html_attributes
  end

  # Hook before rendering
  def before_render
    @formatted_name = @profile.full_name.titleize
  end

  # Conditional rendering
  def render?
    @profile.present? && @profile.active?
  end

  private

  def card_classes
    base = "profile-card"
    variants = {
      default: "profile-card--default",
      compact: "profile-card--compact",
      detailed: "profile-card--detailed"
    }

    "#{base} #{variants[@variant]}"
  end

  def action_classes
    "profile-card__action"
  end

  def html_attributes
    default_attrs = { data: { controller: "profile-card" } }
    default_attrs.merge(@html_attributes)
      .map { |k, v| "#{k}='#{v}'" }
      .join(" ")
      .html_safe
  end
end
```

```erb
<%# app/components/profile_card_component.html.erb %>
<div class="<%= card_classes %>" <%= html_attributes %>>
  <div class="profile-card__header">
    <% if avatar? %>
      <%= avatar %>
    <% else %>
      <div class="profile-card__avatar-placeholder">
        <%= @profile.initials %>
      </div>
    <% end %>

    <div class="profile-card__info">
      <h3 class="profile-card__name"><%= @formatted_name %></h3>
      <% if @show_details %>
        <p class="profile-card__details"><%= @profile.email %></p>
      <% end %>
    </div>

    <% if badge? %>
      <div class="profile-card__badge">
        <%= badge %>
      </div>
    <% end %>
  </div>

  <% if actions? %>
    <div class="profile-card__actions">
      <% actions.each do |action| %>
        <%= action %>
      <% end %>
    </div>
  <% end %>
</div>
```

## Complete RSpec Tests

### Recommended Test Structure

```ruby
# spec/components/profile_card_component_spec.rb
require "rails_helper"

RSpec.describe ProfileCardComponent, type: :component do
  let(:profile) { create(:profile, first_name: "Jane", last_name: "Doe", email: "jane@example.com", active: true) }

  describe "rendering" do
    context "with minimal parameters" do
      it "renders the profile name" do
        render_inline(described_class.new(profile: profile))

        expect(page).to have_css(".profile-card__name", text: "Jane Doe")
      end

      it "does not show details by default" do
        render_inline(described_class.new(profile: profile))

        expect(page).not_to have_css(".profile-card__details")
      end

      it "renders default variant classes" do
        render_inline(described_class.new(profile: profile))

        expect(page).to have_css(".profile-card.profile-card--default")
      end
    end

    context "with show_details: true" do
      it "displays the profile details" do
        render_inline(described_class.new(profile: profile, show_details: true))

        expect(page).to have_css(".profile-card__details", text: "jane@example.com")
      end
    end

    context "with variant: :compact" do
      it "applies compact variant classes" do
        render_inline(described_class.new(profile: profile, variant: :compact))

        expect(page).to have_css(".profile-card.profile-card--compact")
      end
    end

    context "with custom HTML attributes" do
      it "merges custom attributes" do
        render_inline(described_class.new(
          profile: profile,
          id: "custom-id",
          data: { action: "click->modal#open" }
        ))

        expect(page).to have_css("#custom-id[data-action='click->modal#open']")
      end
    end
  end

  describe "slots" do
    context "with avatar slot" do
      it "renders custom avatar content" do
        render_inline(described_class.new(profile: profile)) do |component|
          component.with_avatar do
            "<img src='/avatar.jpg' alt='Avatar'>".html_safe
          end
        end

        expect(page).to have_css("img[src='/avatar.jpg']")
      end
    end

    context "without avatar slot" do
      it "renders placeholder with initials" do
        render_inline(described_class.new(profile: profile))

        expect(page).to have_css(".profile-card__avatar-placeholder", text: profile.initials)
      end
    end

    context "with badge slot" do
      it "renders the badge" do
        render_inline(described_class.new(profile: profile)) do |component|
          component.with_badge do
            "<span class='badge'>Premium</span>".html_safe
          end
        end

        expect(page).to have_css(".profile-card__badge .badge", text: "Premium")
      end
    end

    context "with actions slot" do
      it "renders multiple actions" do
        render_inline(described_class.new(profile: profile)) do |component|
          component.with_action(text: "Edit", url: "/profiles/1/edit")
          component.with_action(text: "Delete", url: "/profiles/1", method: :delete)
        end

        expect(page).to have_link("Edit", href: "/profiles/1/edit")
        expect(page).to have_link("Delete", href: "/profiles/1")
      end
    end
  end

  describe "#render?" do
    context "when profile is active" do
      it "renders the component" do
        render_inline(described_class.new(profile: profile))

        assert_component_rendered
        expect(page).to have_css(".profile-card")
      end
    end

    context "when profile is inactive" do
      let(:inactive_profile) { create(:profile, active: false) }

      it "does not render the component" do
        render_inline(described_class.new(profile: inactive_profile))

        refute_component_rendered
        expect(page).not_to have_css(".profile-card")
      end
    end

    context "when profile is nil" do
      it "does not render the component" do
        render_inline(described_class.new(profile: nil))

        refute_component_rendered
      end
    end
  end
end
```

## Previews for Documentation

```ruby
# spec/components/previews/profile_card_component_preview.rb
class ProfileCardComponentPreview < ViewComponent::Preview
  # Default preview
  # @label Default
  def default
    profile = Profile.new(
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      active: true
    )

    render(ProfileCardComponent.new(profile: profile))
  end

  # Compact variant
  # @label Compact
  def compact
    profile = Profile.new(first_name: "John", last_name: "Smith", active: true)
    render(ProfileCardComponent.new(profile: profile, variant: :compact))
  end

  # With details visible
  # @label With Details
  def with_details
    profile = Profile.new(
      first_name: "Alice",
      last_name: "Johnson",
      email: "alice@example.com",
      active: true
    )

    render(ProfileCardComponent.new(profile: profile, show_details: true))
  end

  # With custom avatar
  # @label With Custom Avatar
  def with_avatar
    profile = Profile.new(first_name: "Bob", last_name: "Wilson", active: true)

    render(ProfileCardComponent.new(profile: profile)) do |component|
      component.with_avatar do
        tag.img(src: "https://i.pravatar.cc/150?img=3", alt: "Avatar", class: "rounded-full w-12 h-12")
      end
    end
  end

  # With badge and actions
  # @label Complete Card
  def with_all_slots
    profile = Profile.new(
      first_name: "Sarah",
      last_name: "Connor",
      email: "sarah@example.com",
      active: true
    )

    render(ProfileCardComponent.new(profile: profile, show_details: true)) do |component|
      component.with_avatar do
        tag.img(src: "https://i.pravatar.cc/150?img=5", alt: "Avatar", class: "rounded-full w-12 h-12")
      end

      component.with_badge do
        tag.span("Premium", class: "badge badge-primary")
      end

      component.with_action(text: "View Profile", url: "#")
      component.with_action(text: "Send Message", url: "#")
    end
  end

  # Dynamic parameters from URL
  # @label Dynamic
  def dynamic(first_name: "Dynamic", last_name: "Profile", show_details: false)
    profile = Profile.new(
      first_name: first_name,
      last_name: last_name,
      email: "#{first_name.downcase}@example.com",
      active: true
    )

    render(ProfileCardComponent.new(profile: profile, show_details: show_details))
  end
end
```

## Collections with ViewComponent

### Collection Rendering

```ruby
# app/components/item_card_component.rb
class ItemCardComponent < ViewComponent::Base
  with_collection_parameter :item

  def initialize(item:, item_counter: nil, item_iteration: nil)
    @item = item
    @counter = item_counter
    @iteration = item_iteration
  end

  def featured?
    @iteration&.first?
  end

  def card_classes
    classes = ["item-card"]
    classes << "item-card--featured" if featured?
    classes.join(" ")
  end
end
```

```erb
<%# app/views/items/index.html.erb %>
<div class="items-grid">
  <%= render(ItemCardComponent.with_collection(@items)) %>
</div>
```

### Collection Test

```ruby
# spec/components/item_card_component_spec.rb
RSpec.describe ItemCardComponent, type: :component do
  describe "collection rendering" do
    let(:items) { create_list(:item, 3) }

    it "renders all items" do
      render_inline(described_class.with_collection(items))

      expect(page).to have_css(".item-card", count: 3)
    end

    it "marks first item as featured" do
      render_inline(described_class.with_collection(items))

      expect(page).to have_css(".item-card--featured", count: 1)
    end
  end
end
```

## Polymorphic Components with Slots

```ruby
# app/components/list_item_component.rb
class ListItemComponent < ViewComponent::Base
  renders_one :visual, types: {
    icon: IconComponent,
    avatar: ->(src:, alt:, **options) do
      AvatarComponent.new(src: src, alt: alt, size: :small, **options)
    end,
    image: ImageComponent
  }

  renders_one :content
  renders_many :actions, "ActionComponent"

  def initialize(title:, **html_attributes)
    @title = title
    @html_attributes = html_attributes
  end

  class ActionComponent < ViewComponent::Base
    def initialize(label:, url:, **html_attributes)
      @label = label
      @url = url
      @html_attributes = html_attributes
    end
  end
end
```

```erb
<%# Usage %>
<%= render(ListItemComponent.new(title: "John Doe")) do |item| %>
  <% item.with_visual_avatar(src: "/avatar.jpg", alt: "John") %>
  <% item.with_content do %>
    <p>Software Engineer</p>
  <% end %>
  <% item.with_action(label: "View", url: "#") %>
  <% item.with_action(label: "Edit", url: "#") %>
<% end %>
```

## Stimulus Integration

```ruby
# app/components/dropdown_component.rb
class DropdownComponent < ViewComponent::Base
  renders_one :trigger
  renders_many :items, "ItemComponent"

  def initialize(position: :bottom, **html_attributes)
    @position = position
    @html_attributes = html_attributes
  end

  def dropdown_data
    {
      controller: "dropdown",
      dropdown_position_value: @position,
      action: "click@window->dropdown#close"
    }
  end

  class ItemComponent < ViewComponent::Base
    def initialize(text:, url: nil, method: :get, **html_attributes)
      @text = text
      @url = url
      @method = method
      @html_attributes = html_attributes
    end
  end
end
```

```erb
<%# app/components/dropdown_component.html.erb %>
<div data-<%= dropdown_data.map { |k, v| "#{k}='#{v}'" }.join(" ") %> class="dropdown">
  <div data-action="click->dropdown#toggle">
    <%= trigger %>
  </div>

  <div data-dropdown-target="menu" class="dropdown-menu hidden">
    <% items.each do |item| %>
      <%= item %>
    <% end %>
  </div>
</div>
```

## i18n Translations

```ruby
# app/components/notification_component.rb
class NotificationComponent < ViewComponent::Base
  def initialize(type: :info)
    @type = type
  end

  def title
    t(".title.#{@type}")
  end

  def icon
    t(".icon.#{@type}")
  end
end
```

```yaml
# app/components/notification_component.yml
en:
  title:
    info: "Information"
    warning: "Warning"
    error: "Error"
    success: "Success"
  icon:
    info: "ℹ️"
    warning: "⚠️"
    error: "❌"
    success: "✅"
```

## Component Creation Workflow

### Step 1: Analyze Requirements

- What is the single responsibility?
- Which parameters are required vs optional?
- Does the component need slots for flexibility?
- What variants or states should it support?
- Are JavaScript interactions necessary?

### Step 2: Generate Component

```bash
bin/rails generate view_component:component Alert type message dismissible --sidecar --preview
```

### Step 3: Implement Component

1. Define initializer with clear API
2. Add slots if necessary
3. Implement private helper methods
4. Add `#render?` if necessary
5. Create template

### Step 4: Write Tests

1. Rendering tests with minimal parameters
2. Tests for each variant/option
3. Tests for each slot (present and absent)
4. Tests for `#render?` if applicable
5. Integration tests with Rails helpers

### Step 5: Create Lookbook Previews

1. Default preview
2. Preview for each variant
3. Preview with all slots filled
4. Preview with dynamic parameters
5. Add descriptive notes to Lookbook

### Step 6: Validate

```bash
# Run tests
bundle exec rspec spec/components/alert_component_spec.rb

# Check linting
bundle exec rubocop -a app/components/alert_component.rb

# Visually check Lookbook previews
# Visit /lookbook
```

## Anti-Patterns to Avoid

### ❌ Business Logic in Components

```ruby
# BAD
class OrderComponent < ViewComponent::Base
  def initialize(order:)
    @order = order
    @total = calculate_total_with_tax_and_discount  # NO!
    @order.update!(processed: true)  # NEVER!
  end
end

# GOOD
class OrderComponent < ViewComponent::Base
  def initialize(order:, total:)
    @order = order
    @total = total  # Receives already calculated data
  end
end
```

### ❌ Overly Generic Components

```ruby
# BAD - Too abstract
class GenericComponent < ViewComponent::Base
  def initialize(type:, data:, options: {})
    # Too flexible = difficult to maintain
  end
end

# GOOD - Specific and clear
class ProfileHeaderComponent < ViewComponent::Base
  def initialize(profile:, show_actions: false)
    @profile = profile
    @show_actions = show_actions
  end
end
```

### ❌ Hidden Dependencies

```ruby
# BAD - Depends on global variables
class NavigationComponent < ViewComponent::Base
  def initialize
    @user = Current.user  # Hidden coupling
  end
end

# GOOD - Explicit dependencies
class NavigationComponent < ViewComponent::Base
  def initialize(user:)
    @user = user
  end
end
```

## Commands

**Generate component:**
```bash
bin/rails generate view_component:component Button text size
bin/rails generate view_component:component Button text --sidecar --preview
```

**Run tests:**
```bash
bundle exec rspec spec/components/
bundle exec rspec spec/components/button_component_spec.rb
```

**View previews:**
Start server and visit `/rails/view_components` or `/lookbook`

**Lint components:**
```bash
bundle exec rubocop -a app/components/
```

## Boundaries

### ✅ Always Do

- Component has single clear responsibility
- Required parameters are explicit
- Default values are sensible
- Private methods are truly private
- Write rendering tests with minimal parameters
- Test all variants/options
- Test all slots (present and absent)
- Create Lookbook previews
- Coverage ≥ 95%
- No N+1 queries
- Verify accessibility

### ⚠️ Ask First

- Before adding database queries to components
- Before creating deeply nested components
- Before adding complex business logic
- Before modifying existing component APIs

### 🚫 Never Do

- Put business logic in components
- Modify data or create side effects
- Make external API calls
- Create overly generic components
- Use hidden dependencies (Current.user)
- Skip tests or previews
- Ignore accessibility
- Create components without clear API

## Checklist Before Submitting

✅ **Code:**
- [ ] Single clear responsibility
- [ ] Required parameters explicit
- [ ] Default values sensible
- [ ] Private methods truly private

✅ **Tests:**
- [ ] Rendering tests with minimal parameters
- [ ] Tests for all variants/options
- [ ] Tests for all slots
- [ ] Tests for `#render?` if applicable
- [ ] Coverage ≥ 95%

✅ **Documentation:**
- [ ] Lookbook preview with default scenario
- [ ] Lookbook previews for main variants
- [ ] Descriptive notes in Lookbook
- [ ] i18n file if necessary

✅ **Quality:**
- [ ] RuboCop passes
- [ ] No N+1 queries
- [ ] Accessibility verified
- [ ] Responsive design tested

## Key Takeaways

- Create components with **single responsibility**
- Use **slots** for flexible composition
- Write **comprehensive tests** (≥ 95% coverage)
- Create **Lookbook previews** for documentation
- Follow **SOLID principles**
- Favor **composition over inheritance**
- Components are **presentational** - no business logic
- Be **pragmatic** - don't over-engineer
