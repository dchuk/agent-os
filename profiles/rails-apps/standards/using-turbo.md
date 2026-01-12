---
name: using-turbo
description: Builds reactive UIs with Turbo Frames, Streams, Drive, and morphing for real-time updates without JavaScript frameworks
---

You are an expert in Hotwire Turbo for Rails applications, specializing in creating fast, reactive UIs with HTML-over-the-wire.

## Quick Start

**When to use this skill:**
- Building real-time UI updates without full page reloads
- Creating partial page updates with Turbo Frames
- Broadcasting live updates via WebSockets
- Implementing modals, inline editing, and lazy loading
- Optimizing perceived performance with page morphing

**Core philosophy:** Turbo is plenty. No React, Vue, or Alpine needed. Turbo Streams + Turbo Frames + morphing = rich, reactive UIs with server-rendered HTML.

## Core Principles

### Turbo 8 Features (Rails 8+)

1. **Page Refresh with Morphing:** Smart DOM updates that preserve state
2. **View Transitions:** Built-in CSS view transitions
3. **Streams over WebSocket:** Real-time updates via ActionCable
4. **Native Prefetch:** Automatic link prefetching on hover

### What Turbo Provides

✅ Partial page updates (no full reloads)
✅ Real-time broadcasts via WebSockets
✅ Optimistic UI updates
✅ Smooth page transitions
✅ Mobile-app-like navigation
✅ Standard Rails views

### What You DON'T Need

❌ React/Vue/Svelte
❌ Client-side state management
❌ API-only backends
❌ Complex build pipelines
❌ Duplicate validation logic

## Turbo Drive

### How It Works

Turbo Drive intercepts link clicks and form submissions, fetches pages via AJAX, and swaps `<body>` content for instant navigation.

### Configuration

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <meta name="turbo-refresh-method" content="morph">
  <meta name="turbo-refresh-scroll" content="preserve">
  <%= turbo_refreshes_with method: :morph, scroll: :preserve %>
</head>
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_turbo_refresh_method

  private

  def set_turbo_refresh_method
    turbo_refreshes_with method: :morph, scroll: :preserve
  end
end
```

### Disabling Turbo Drive

```erb
<%# Disable for specific link %>
<%= link_to "External", external_url, data: { turbo: false } %>

<%# Disable for form %>
<%= form_with model: @resource, data: { turbo: false } do |f| %>
<% end %>

<%# Disable for section %>
<div data-turbo="false">
  <%# All links/forms here bypass Turbo %>
</div>
```

### Prefetching Links

```erb
<%# Default: prefetch on hover %>
<%= link_to "Resource", resource_path(@resource) %>

<%# Disable prefetch %>
<%= link_to "Heavy Page", heavy_path, data: { turbo_prefetch: false } %>

<%# Eager prefetch %>
<%= link_to "Important", important_path, data: { turbo_prefetch: "eager" } %>
```

## Turbo Frames

Turbo Frames enable partial page updates by targeting specific sections of the DOM.

### Basic Frame Structure

```erb
<%# app/views/resources/index.html.erb %>
<%= turbo_frame_tag "resources" do %>
  <% @resources.each do |resource| %>
    <%= render resource %>
  <% end %>
  <%= paginate @resources %>
<% end %>
```

### Frame Navigation

```erb
<%# Link navigates within frame %>
<%= turbo_frame_tag dom_id(@resource) do %>
  <%= link_to @resource.name, edit_resource_path(@resource) %>
<% end %>

<%# edit.html.erb must have matching frame %>
<%= turbo_frame_tag dom_id(@resource) do %>
  <%= render "form", resource: @resource %>
<% end %>
```

### Breaking Out of Frames

```erb
<%# Navigate full page %>
<%= link_to "View All", resources_path, data: { turbo_frame: "_top" } %>

<%# Target different frame %>
<%= link_to "Preview", preview_path, data: { turbo_frame: "preview_panel" } %>

<%# Form submits to full page %>
<%= form_with model: @resource, data: { turbo_frame: "_top" } do |f| %>
<% end %>
```

### Lazy Loading Frames

```erb
<%# Load when frame enters viewport %>
<%= turbo_frame_tag "comments",
                    src: comments_path(@post),
                    loading: :lazy do %>
  <div class="loading">Loading comments...</div>
<% end %>
```

### Inline Editing Pattern

```erb
<%# app/views/resources/_resource.html.erb %>
<%= turbo_frame_tag dom_id(resource) do %>
  <div class="resource-card">
    <h3><%= resource.name %></h3>
    <%= link_to "Edit", edit_resource_path(resource) %>
  </div>
<% end %>

<%# app/views/resources/edit.html.erb %>
<%= turbo_frame_tag dom_id(@resource) do %>
  <%= render "form", resource: @resource %>
<% end %>
```

### Modal Pattern

```erb
<%# app/views/resources/index.html.erb %>
<%= turbo_frame_tag "modal" %>
<%= link_to "New Resource", new_resource_path, data: { turbo_frame: "modal" } %>

<%# app/views/resources/new.html.erb %>
<%= turbo_frame_tag "modal" do %>
  <div class="modal">
    <%= form_with model: @resource, data: { turbo_frame: "_top" } do |f| %>
      <%= f.text_field :name %>
      <%= f.submit "Create" %>
    <% end %>
    <%= link_to "Cancel", resources_path, data: { turbo_frame: "_top" } %>
  </div>
<% end %>
```

## Turbo Streams

Turbo Streams enable surgical DOM updates with seven built-in actions plus custom actions.

### Stream Actions

| Action | Description | Usage |
|--------|-------------|-------|
| `append` | Add to end of target | Add item to list bottom |
| `prepend` | Add to beginning | Add item to list top |
| `replace` | Replace entire element | Update a resource |
| `update` | Replace content only | Update inner HTML |
| `remove` | Delete element | Remove from list |
| `before` | Insert before target | Insert above |
| `after` | Insert after target | Insert below |
| `morph` | Smart replacement (Turbo 8) | Preserve state |
| `refresh` | Trigger page refresh | Full page morph |

### Controller Response

```ruby
# app/controllers/resources_controller.rb
class ResourcesController < ApplicationController
  def create
    @resource = Resource.new(resource_params)

    respond_to do |format|
      if @resource.save
        format.turbo_stream  # Renders create.turbo_stream.erb
        format.html { redirect_to @resource, notice: "Created!" }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "resource_form",
            partial: "form",
            locals: { resource: @resource }
          )
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @resource = Resource.find(params[:id])
    @resource.destroy!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to resources_path, notice: "Deleted!" }
    end
  end
end
```

### Stream Templates

```erb
<%# app/views/resources/create.turbo_stream.erb %>

<%# Add new resource to list %>
<%= turbo_stream.prepend "resources" do %>
  <%= render @resource %>
<% end %>

<%# Clear form %>
<%= turbo_stream.replace "resource_form" do %>
  <%= render "form", resource: Resource.new %>
<% end %>

<%# Show flash %>
<%= turbo_stream.prepend "flash" do %>
  <div class="flash flash--success">Resource created!</div>
<% end %>
```

```erb
<%# app/views/resources/destroy.turbo_stream.erb %>
<%= turbo_stream.remove dom_id(@resource) %>

<%= turbo_stream.prepend "flash" do %>
  <div class="flash flash--info">Resource deleted!</div>
<% end %>
```

### Multiple Streams in One Response

```erb
<%# app/views/resources/update.turbo_stream.erb %>
<%= turbo_stream.replace dom_id(@resource), @resource %>
<%= turbo_stream.update "resources_count", @resources.count %>
<%= turbo_stream.prepend "flash" do %>
  <div class="flash flash--success">Updated!</div>
<% end %>
```

### Inline Turbo Streams (Controller)

```ruby
def toggle_favorite
  @resource = Resource.find(params[:id])
  @resource.toggle_favorite!(current_user)

  render turbo_stream: [
    turbo_stream.replace(
      dom_id(@resource, :favorite_button),
      partial: "favorite_button",
      locals: { resource: @resource }
    ),
    turbo_stream.update("favorites_count", current_user.favorites.count)
  ]
end
```

## Broadcasts (Real-time Updates)

### Model Broadcasting

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :chat

  after_create_commit -> {
    broadcast_prepend_to chat, target: "messages"
  }

  after_update_commit -> {
    broadcast_replace_to chat
  }

  after_destroy_commit -> {
    broadcast_remove_to chat
  }
end
```

### View Subscription

```erb
<%# app/views/chats/show.html.erb %>
<h1><%= @chat.name %></h1>

<%# Subscribe to real-time updates %>
<%= turbo_stream_from @chat %>

<div id="messages">
  <%= render @chat.messages %>
</div>
```

### Custom Broadcasts

```ruby
# app/models/notification.rb
class Notification < ApplicationRecord
  belongs_to :user

  after_create_commit :broadcast_to_user

  private

  def broadcast_to_user
    broadcast_prepend_to(
      "user_#{user_id}_notifications",
      target: "notifications",
      partial: "notifications/notification",
      locals: { notification: self }
    )
  end
end
```

```erb
<%# Subscribe in layout %>
<% if current_user %>
  <%= turbo_stream_from "user_#{current_user.id}_notifications" %>
<% end %>

<div id="notifications"></div>
```

### Manual Broadcasting

```ruby
# Broadcast to all board viewers
Turbo::StreamsChannel.broadcast_append_to(
  @board,
  :cards,
  target: "cards",
  partial: "cards/card",
  locals: { card: @card }
)

# Broadcast to specific user
Turbo::StreamsChannel.broadcast_replace_to(
  "user_#{@user.id}",
  target: dom_id(@notification),
  partial: "notifications/notification",
  locals: { notification: @notification }
)
```

## Morphing (Turbo 8)

### When to Use Morphing

Use `turbo_stream.morph` instead of `replace` when:
- The element has form inputs (preserves focus/cursor)
- The element has scroll position to maintain
- The element has Stimulus controllers (preserves state)
- You want smoother transitions

```ruby
# app/controllers/resources_controller.rb
def update
  @resource.update!(resource_params)

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.morph(
        dom_id(@resource, :container),
        partial: "resources/container",
        locals: { resource: @resource.reload }
      )
    end
    format.html { redirect_to @resource }
  end
end
```

### Permanent Elements

```erb
<%# Element persists across page loads %>
<div id="<%= dom_id(@resource) %>" data-turbo-permanent>
  <video controls autoplay></video>
</div>

<%# Element always replaced, never morphed %>
<div id="sidebar" data-turbo-morph="false">
</div>
```

### Page Refresh with Morphing

```ruby
# Trigger refresh after background job
def after_import
  Turbo::StreamsChannel.broadcast_refresh_to(@board)
end

# Refresh specific users
def notify_status_change
  @resource.watchers.each do |watcher|
    Turbo::StreamsChannel.broadcast_refresh_to("user_#{watcher.id}")
  end
end
```

## Common Patterns

### Flash Messages with Turbo

```erb
<%# app/views/shared/_flash.html.erb %>
<div class="flash flash--<%= type %>"
     data-controller="auto-dismiss"
     data-auto-dismiss-delay-value="5000">
  <%= message %>
  <button data-action="auto-dismiss#dismiss">×</button>
</div>
```

```erb
<%# Include in Turbo Stream responses %>
<%= turbo_stream.prepend "flash" do %>
  <%= render "shared/flash", type: :success, message: "Saved!" %>
<% end %>
```

### Optimistic UI Updates

```erb
<%# Immediate feedback with Turbo Frame %>
<%= turbo_frame_tag dom_id(resource, :star) do %>
  <%= button_to resource_star_path(resource),
      method: resource.starred? ? :delete : :post,
      class: "star-button",
      data: { turbo_frame: dom_id(resource, :star) } do %>
    <%= resource.starred? ? "★" : "☆" %>
  <% end %>
<% end %>
```

### Empty State Handling

```erb
<%# app/views/resources/index.html.erb %>
<div id="resources">
  <% if @resources.any? %>
    <%= render @resources %>
  <% else %>
    <div id="empty_state">
      <p>No resources yet.</p>
    </div>
  <% end %>
</div>
```

```erb
<%# app/views/resources/create.turbo_stream.erb %>
<%= turbo_stream.remove "empty_state" %>
<%= turbo_stream.prepend "resources", @resource %>
```

### Infinite Scroll

```erb
<%# app/views/resources/index.html.erb %>
<div id="resources">
  <%= render @resources %>
</div>

<%= turbo_frame_tag "pagination",
                    src: resources_path(page: @next_page),
                    loading: :lazy do %>
  <div class="loading">Loading more...</div>
<% end %>
```

## Testing Turbo

### Request Specs

```ruby
# spec/requests/resources_spec.rb
RSpec.describe "Resources", type: :request do
  describe "POST /resources" do
    it "returns turbo stream" do
      post resources_path,
           params: { resource: { name: "Test" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="prepend"')
    end

    it "falls back to HTML redirect" do
      post resources_path, params: { resource: { name: "Test" } }

      expect(response).to redirect_to(Resource.last)
    end
  end
end
```

### System Tests

```ruby
# test/system/resources_test.rb
class ResourcesTest < ApplicationSystemTestCase
  test "creating a resource" do
    visit resources_path

    fill_in "Name", with: "Test Resource"
    click_button "Create"

    # Turbo Stream inserts without page reload
    assert_text "Test Resource"
    assert_selector "#resources .resource", count: 1
  end

  test "real-time update appears" do
    visit resources_path

    # Simulate another user creating resource
    using_session(:other_user) do
      Resource.create!(name: "From another user")
    end

    # Resource appears via broadcast
    assert_text "From another user"
  end
end
```

## Commands

**Test Turbo Stream:**
```bash
curl -H "Accept: text/vnd.turbo-stream.html" http://localhost:3000/resources
```

**Check broadcasts:**
```ruby
bin/rails console
Turbo::StreamsChannel.broadcast_*
```

**Run dev:**
```bash
bin/dev
```

**Test:**
```bash
bin/rails test test/system/
bundle exec rspec spec/requests/
```

## Boundaries

### ✅ Always Do

- Use Turbo Streams for create/update/destroy responses
- Broadcast changes to relevant streams
- Use `dom_id` for consistent element IDs
- Provide fallback HTML responses
- Use morphing for form-heavy updates
- Lazy load expensive content with frames
- Test Turbo responses
- Handle errors gracefully

### ⚠️ Ask First

- Before adding JavaScript frameworks (React/Vue)
- Before using Turbo for complex real-time apps (consider polling)
- Before broadcasting to many users (performance impact)
- Before using Turbo Frames for navigation (can be confusing)
- Before disabling Turbo Drive globally

### 🚫 Never Do

- Mix Turbo with client-side rendering frameworks
- Forget Turbo Stream format responses
- Use inline `<turbo-stream>` tags (use helpers)
- Broadcast on every tiny change (debounce)
- Skip `turbo_stream_from` subscription in views
- Use Turbo for file uploads (use direct upload)
- Forget CSRF tokens in AJAX requests
- Create frames without IDs
- Skip HTML fallbacks
- Break browser history with improper frame usage

## Key Takeaways

- **HTML-over-the-wire** - Turbo sends HTML, not JSON
- **Progressive enhancement** - Always provide HTML fallbacks
- **Frames for scoping** - Update parts of the page
- **Streams for precision** - Surgical DOM updates
- **Stable IDs are crucial** - Use `dom_id` for consistent targeting
- **Test your streams** - Request specs verify Turbo responses
- **Morphing is powerful** - Turbo 8's morphing preserves state
- Be **pragmatic** - Don't over-engineer simple interactions
