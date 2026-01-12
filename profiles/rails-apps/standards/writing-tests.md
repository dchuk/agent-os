---
name: writing-tests
description: Writes Minitest tests with fixtures for Rails applications, focusing on integration tests over unit tests
---

# Writing Tests Skill

Use this skill to write fast, readable tests for Rails applications using Minitest and fixtures.

## Quick Start

```ruby
# Model test
class CardTest < ActiveSupport::TestCase
  test "closes card and creates closure" do
    card = cards(:logo)
    card.close

    assert card.closed?
    assert_not_nil card.closed_at
  end
end

# Controller test
class CardsControllerTest < ActionDispatch::IntegrationTest
  test "creates card" do
    sign_in_as users(:david)

    assert_difference -> { Card.count }, 1 do
      post board_cards_path(boards(:projects)), params: {
        card: { title: "New card", column_id: columns(:backlog).id }
      }
    end

    assert_redirected_to card_path(Card.last)
  end
end
```

## Core Principles

### 1. Minitest Only (NOT RSpec)

Use Minitest's plain Ruby syntax, not RSpec's DSL.

```ruby
# GOOD - Minitest
test "validates title presence" do
  @card.title = nil
  assert_not @card.valid?
end

# BAD - Don't use RSpec
it "validates title presence" do
  @card.title = nil
  expect(@card).not_to be_valid
end
```

**Why Minitest:**
- Plain Ruby (no DSL to learn)
- Faster test suite
- Part of Rails (no extra gem)
- Simpler setup
- Easier to debug

### 2. Fixtures Only (NOT FactoryBot)

Use YAML fixtures, not factories.

```ruby
# GOOD - Fixtures
setup do
  @card = cards(:logo)
  @user = users(:david)
end

# BAD - Don't use FactoryBot
setup do
  @card = FactoryBot.create(:card)
  @user = FactoryBot.create(:user)
end
```

**Why fixtures:**
- 10-100x faster (loaded once per test suite)
- Shared across all tests (consistency)
- Force you to think about real data
- No factory DSL to maintain
- Easier to understand (YAML vs Ruby)

Configure in `test_helper.rb`:

```ruby
class ActiveSupport::TestCase
  fixtures :all  # Load all fixtures
end
```

### 3. Integration Tests Over Unit Tests

Test features through the full stack when possible.

```ruby
# PREFERRED - Integration test
class CardsControllerTest < ActionDispatch::IntegrationTest
  test "closing card updates status" do
    sign_in_as users(:david)
    card = cards(:logo)

    patch close_card_path(card)

    assert_redirected_to card_path(card)
    assert card.reload.closed?
  end
end

# ACCEPTABLE - Unit test for complex logic
class CardTest < ActiveSupport::TestCase
  test "position calculation with gaps" do
    # Test complex positioning algorithm
  end
end
```

**Test Pyramid:**
- Few system tests (Capybara, full browser)
- Many integration tests (controller + model)
- Some unit tests (complex logic only)

### 4. Test Behavior Not Implementation

Focus on outcomes, not internal mechanisms.

```ruby
# GOOD - Tests behavior
test "closing card makes it unavailable in active scope" do
  card = cards(:logo)
  card.close

  assert_not_includes Card.active, card
  assert card.closed?
end

# BAD - Tests implementation
test "close method calls create_closure" do
  card = cards(:logo)
  card.expects(:create_closure!)
  card.close
end
```

## Patterns

### Fixture Patterns

#### Basic Fixture Structure

```yaml
# test/fixtures/cards.yml
logo:
  id: d0f1c2e3-4b5a-6789-0123-456789abcdef
  account: 37s
  board: projects
  column: backlog
  creator: david
  title: "Design new logo"
  body: "Need a fresh logo for the homepage"
  status: published
  position: 1
  created_at: <%= 2.days.ago %>
  updated_at: <%= 1.day.ago %>

draft_card:
  account: 37s
  board: projects
  column: backlog
  creator: david
  title: "Draft card"
  status: draft
  position: 2
```

#### Fixture Associations

```yaml
# Reference other fixtures by name
# test/fixtures/users.yml
david:
  identity: david        # References identities(:david)
  account: 37s          # References accounts(:37s)
  full_name: "David Heinemeier Hansson"

# test/fixtures/identities.yml
david:
  email_address: "david@example.com"
  password_digest: <%= BCrypt::Password.create('password', cost: 4) %>
```

#### ERB in Fixtures

```yaml
# Dynamic dates
recent_card:
  created_at: <%= 1.hour.ago %>
  updated_at: <%= 30.minutes.ago %>

# Calculations
expensive_item:
  price: <%= 100 * 1.5 %>

# Conditionals
<% if ENV['FULL_FIXTURES'] %>
extra_card:
  title: "Extra fixture"
<% end %>
```

#### YAML Anchors for DRY Fixtures

```yaml
# Base template
card_defaults: &card_defaults
  account: 37s
  board: projects
  creator: david
  status: published

# Inherit from template
card_one:
  <<: *card_defaults
  title: "Card One"
  position: 1

card_two:
  <<: *card_defaults
  title: "Card Two"
  position: 2
```

### Model Test Patterns

```ruby
require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
    @user = users(:david)
  end

  test "fixtures are valid" do
    assert @card.valid?
  end

  test "requires title" do
    @card.title = nil

    assert_not @card.valid?
    assert_includes @card.errors[:title], "can't be blank"
  end

  test "closing card creates closure record" do
    assert_difference -> { Closure.count }, 1 do
      @card.close(user: @user)
    end

    assert @card.closed?
    assert_equal @user, @card.closed_by
  end

  # Testing associations
  test "belongs to board" do
    assert_instance_of Board, @card.board
    assert_equal boards(:projects), @card.board
  end

  test "destroys dependent comments" do
    comment_ids = @card.comments.pluck(:id)

    @card.destroy!

    comment_ids.each do |id|
      assert_nil Comment.find_by(id: id)
    end
  end

  # Testing scopes
  test "open scope excludes closed cards" do
    @card.close

    assert_not_includes Card.open, @card
    assert_includes Card.closed, @card
  end

  # Testing enums
  test "status enum" do
    @card.status_draft!
    assert @card.status_draft?

    @card.status_published!
    assert @card.status_published?

    assert_includes Card.status_published, @card
  end
end
```

### Controller/Integration Test Patterns

```ruby
require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @card = cards(:logo)
    @user = users(:david)
    sign_in_as @user
  end

  test "should get index" do
    get board_cards_path(@card.board)

    assert_response :success
    assert_select "h1", "Cards"
  end

  test "should create card" do
    assert_difference -> { Card.count }, 1 do
      post board_cards_path(@card.board), params: {
        card: {
          title: "New card",
          body: "Card body",
          column_id: @card.column_id
        }
      }
    end

    assert_redirected_to card_path(Card.last)
    assert_equal "Card created", flash[:notice]
  end

  test "should update card" do
    patch card_path(@card), params: {
      card: { title: "Updated title" }
    }

    assert_redirected_to card_path(@card)
    assert_equal "Updated title", @card.reload.title
  end

  # Testing authentication
  test "requires authentication" do
    sign_out

    get card_path(@card)

    assert_redirected_to new_session_path
  end

  # Testing Turbo Stream responses
  test "create returns turbo stream" do
    post card_comments_path(@card),
      params: { comment: { body: "Great work!" } },
      as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match /turbo-stream/, response.body
  end

  # Testing JSON API
  test "returns json" do
    get card_path(@card), as: :json

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @card.id, json["id"]
    assert_equal @card.title, json["title"]
  end
end
```

### System Test Patterns

```ruby
require "application_system_test_case"

class CardsTest < ApplicationSystemTestCase
  setup do
    @card = cards(:logo)
    @user = users(:david)
    sign_in_as @user
  end

  test "creating a card" do
    visit board_path(@card.board)

    click_link "New Card"

    fill_in "Title", with: "New feature"
    fill_in "Body", with: "Implement this feature"

    click_button "Create Card"

    assert_text "Card created"
    assert_text "New feature"
  end

  test "closing a card" do
    visit card_path(@card)

    click_button "Close"

    assert_text "Closed"
    assert_selector ".card--closed"
  end

  test "adding a comment" do
    visit card_path(@card)

    fill_in "Body", with: "Great work!"
    click_button "Add Comment"

    # Turbo Stream inserts without page reload
    assert_text "Great work!"
    assert_selector ".comment", text: "Great work!"
  end

  # Testing real-time updates
  test "real-time updates via Turbo Streams" do
    visit card_path(@card)

    # Simulate another user adding a comment
    using_session(:other_user) do
      sign_in_as users(:jason)
      visit card_path(@card)

      fill_in "Body", with: "From another user"
      click_button "Add Comment"
    end

    # Comment appears via Turbo Stream broadcast
    assert_text "From another user"
  end
end
```

### Job Test Patterns

```ruby
require "test_helper"

class NotifyRecipientsJobTest < ActiveJob::TestCase
  test "enqueues job" do
    comment = comments(:logo_comment)

    assert_enqueued_with job: NotifyRecipientsJob, args: [comment] do
      NotifyRecipientsJob.perform_later(comment)
    end
  end

  test "creates notifications for recipients" do
    comment = comments(:logo_comment)

    assert_difference -> { Notification.count }, 2 do
      NotifyRecipientsJob.perform_now(comment)
    end
  end

  test "doesn't notify comment creator" do
    comment = comments(:logo_comment)
    creator_id = comment.creator_id

    NotifyRecipientsJob.perform_now(comment)

    refute Notification.exists?(recipient_id: creator_id, notifiable: comment)
  end
end
```

### Mailer Test Patterns

```ruby
require "test_helper"

class MagicLinkMailerTest < ActionMailer::TestCase
  test "sign in instructions" do
    magic_link = magic_links(:david_sign_in)
    email = MagicLinkMailer.sign_in_instructions(magic_link)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["david@example.com"], email.to
    assert_equal "Sign in to App", email.subject
    assert_match magic_link.code, email.body.to_s
  end
end
```

## Commands

```bash
# Run all tests
bin/rails test

# Run specific file
bin/rails test test/models/card_test.rb

# Run single test by line number
bin/rails test test/models/card_test.rb:14

# Run with coverage
COVERAGE=true bin/rails test

# Parallel tests
bin/rails test:parallel

# System tests only
bin/rails test:system

# Model tests only
bin/rails test:models

# Controller tests only
bin/rails test:controllers
```

## Common Assertions

```ruby
# Value assertions
assert_equal expected, actual
assert_not_equal expected, actual
assert_nil value
assert_not_nil value
assert value, "Must be truthy"
refute value, "Must be falsy"

# Inclusion assertions
assert_includes collection, item
assert_not_includes collection, item

# Response assertions
assert_response :success
assert_response :redirect
assert_response :not_found

# Redirect assertions
assert_redirected_to path

# Difference assertions
assert_difference -> { Model.count }, 1 do
  # code that changes count
end

assert_no_difference -> { Model.count } do
  # code that shouldn't change count
end

# Exception assertions
assert_raises ActiveRecord::RecordInvalid do
  # code that should raise
end

# DOM assertions (integration tests)
assert_select "h1", "Title"
assert_select ".card", count: 3

# System test assertions
assert_text "Expected text"
assert_no_text "Should not appear"
assert_selector ".css-class"
assert_no_selector ".should-not-exist"
```

## Test Helper Setup

```ruby
# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Load all fixtures
  fixtures :all

  # Parallel tests for speed
  parallelize(workers: :number_of_processors)
end

class ActionDispatch::IntegrationTest
  # Sign in helper
  def sign_in_as(user)
    session_record = user.identity.sessions.create!
    cookies.signed[:session_token] = session_record.token

    Current.user = user
    Current.identity = user.identity
    Current.session = session_record
  end

  def sign_out
    cookies.delete(:session_token)
    Current.reset
  end
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome
end
```

## Fixture Best Practices

### 1. Name Fixtures Descriptively

```yaml
# GOOD - Describes what it represents
active_card:
closed_card:
golden_card:
draft_card:

# BAD - Generic numbering
card_1:
card_2:
card_3:
```

### 2. Use Association Names

```yaml
# GOOD - Reference by name
logo:
  creator: david
  board: projects

# BAD - Use IDs
logo:
  creator_id: 1
  board_id: 1
```

### 3. Keep Fixtures Minimal

```yaml
# Only include what's necessary
# Let Rails handle timestamps, IDs, etc.
logo:
  title: "Design new logo"
  creator: david
  board: projects
```

### 4. Create Realistic Data

```yaml
# GOOD - Realistic
david:
  full_name: "David Heinemeier Hansson"
  email_address: "david@example.com"

# BAD - Generic test data
user_1:
  full_name: "Test User"
  email_address: "test@test.com"
```

## Anti-Patterns to Avoid

### Don't Use RSpec

```ruby
# BAD - RSpec syntax
describe Card do
  it "validates title" do
    expect(card).to be_valid
  end
end

# GOOD - Minitest
class CardTest < ActiveSupport::TestCase
  test "validates title" do
    assert @card.valid?
  end
end
```

### Don't Use FactoryBot

```ruby
# BAD - FactoryBot
let(:card) { create(:card) }

# GOOD - Fixtures
setup do
  @card = cards(:logo)
end
```

### Don't Test Implementation Details

```ruby
# BAD - Testing internals
test "calls create_closure method" do
  @card.expects(:create_closure!)
  @card.close
end

# GOOD - Test behavior
test "closing creates closure record" do
  @card.close
  assert @card.closed?
end
```

### Don't Create Unnecessary Data

```ruby
# BAD - Creating when fixtures exist
setup do
  @user = User.create!(name: "Test")
  @card = Card.create!(title: "Test", user: @user)
end

# GOOD - Use fixtures
setup do
  @user = users(:david)
  @card = cards(:logo)
end
```

### Don't Test Rails Functionality

```ruby
# BAD - Rails already tests this
test "validates presence of title" do
  @card.title = nil
  assert_not @card.valid?
end

# GOOD - Only test custom validations
test "validates title doesn't contain profanity" do
  @card.title = "bad word"
  assert_not @card.valid?
  assert_includes @card.errors[:title], "contains inappropriate content"
end
```

## Boundaries

**Always do:**
- Use Minitest (never RSpec)
- Use fixtures (never FactoryBot or factories)
- Include `fixtures :all` in test_helper.rb
- Test behavior, not implementation
- Write integration tests for features
- Test happy path and edge cases
- Use descriptive test names with `test "description" do`
- Clean up in teardown if needed
- Run tests before committing

**Ask first:**
- Before testing private methods (prefer testing public interface)
- Before testing Rails core functionality (already tested by Rails)
- Before creating test data in setup (prefer using fixtures)
- Before using mocks/stubs (prefer real objects and fixtures)
- Before adding system tests (consider if integration test is sufficient)

**Never do:**
- Use RSpec or its DSL (`describe`, `it`, `let`, `before`, `expect`)
- Use FactoryBot, Factory Girl, or any factory library
- Skip writing tests for new features
- Test implementation details or private methods
- Create unnecessary test data (use fixtures instead)
- Leave failing tests in the codebase
- Forget to test error cases and validations
- Test every possible edge case (diminishing returns)
- Use `assert true` or meaningless assertions
