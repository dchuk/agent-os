---
name: tracking-events
description: Builds domain event tracking and activity feeds when capturing business events for auditing and webhooks
---

You are an expert in implementing event tracking, activity feeds, and webhook systems for Rails applications.

## Quick Start

Create rich domain event models instead of generic event tables:

```bash
rails generate model CardMoved card:references from_column:references to_column:references creator:references account:references
```

```ruby
# app/models/card_moved.rb
class CardMoved < ApplicationRecord
  belongs_to :card
  belongs_to :from_column, class_name: "Column"
  belongs_to :to_column, class_name: "Column"
  belongs_to :creator
  belongs_to :account

  has_one :activity, as: :subject, dependent: :destroy

  after_create_commit :create_activity
  after_create_commit :deliver_webhooks_later

  def description
    "#{creator.name} moved #{card.title} from #{from_column.name} to #{to_column.name}"
  end

  private

  def create_activity
    Activity.create!(
      subject: self,
      account: account,
      creator: creator,
      board: card.board
    )
  end

  def deliver_webhooks_later
    WebhookDeliveryJob.perform_later("card.moved", self)
  end
end
```

## Core Principles

**Events as Domain Records, Not Generic Tracking**

1. **Rich Domain Models** - CardMoved, CommentAdded, not Event with type string
2. **Polymorphic Activities** - Activity references actual domain events
3. **Database-Backed** - Use Solid Queue for webhooks, PostgreSQL for events
4. **State as Records** - TrackingEvent models, not boolean fields
5. **Automatic Webhooks** - Events trigger webhook deliveries via background jobs

## Patterns

### Pattern 1: Domain Event Records

```ruby
# app/models/card_moved.rb
class CardMoved < ApplicationRecord
  belongs_to :card
  belongs_to :from_column, class_name: "Column"
  belongs_to :to_column, class_name: "Column"
  belongs_to :creator
  belongs_to :account

  has_one :activity, as: :subject, dependent: :destroy

  after_create_commit :create_activity
  after_create_commit :broadcast_update_later
  after_create_commit :deliver_webhooks_later

  validates :card, :from_column, :to_column, :account, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_card, ->(card) { where(card: card) }
  scope :for_board, ->(board) { joins(:card).where(cards: { board: board }) }

  def description
    "#{creator.name} moved #{card.title} from #{from_column.name} to #{to_column.name}"
  end

  private

  def create_activity
    Activity.create!(
      subject: self,
      account: account,
      creator: creator,
      board: card.board
    )
  end

  def broadcast_update_later
    card.broadcast_replace_later
  end

  def deliver_webhooks_later
    WebhookDeliveryJob.perform_later("card.moved", self)
  end
end

# app/models/comment_added.rb
class CommentAdded < ApplicationRecord
  belongs_to :comment
  belongs_to :card
  belongs_to :creator
  belongs_to :account

  has_one :activity, as: :subject, dependent: :destroy

  after_create_commit :create_activity
  after_create_commit :notify_subscribers_later
  after_create_commit :deliver_webhooks_later

  def description
    "#{creator.name} commented on #{card.title}"
  end

  private

  def create_activity
    Activity.create!(
      subject: self,
      account: account,
      creator: creator,
      board: card.board
    )
  end

  def notify_subscribers_later
    card.subscribers.each do |subscriber|
      CommentNotificationMailer.new_comment(comment, subscriber).deliver_later
    end
  end

  def deliver_webhooks_later
    WebhookDeliveryJob.perform_later("comment.added", self)
  end
end

# app/models/member_invited.rb
class MemberInvited < ApplicationRecord
  belongs_to :membership
  belongs_to :inviter, class_name: "User"
  belongs_to :invitee, class_name: "User"
  belongs_to :account

  has_one :activity, as: :subject, dependent: :destroy

  after_create_commit :create_activity
  after_create_commit :send_invitation_email_later
  after_create_commit :deliver_webhooks_later

  def description
    "#{inviter.name} invited #{invitee.email} to #{account.name}"
  end

  private

  def create_activity
    Activity.create!(
      subject: self,
      account: account,
      creator: inviter
    )
  end

  def send_invitation_email_later
    MembershipMailer.invitation(membership).deliver_later
  end

  def deliver_webhooks_later
    WebhookDeliveryJob.perform_later("member.invited", self)
  end
end
```

### Pattern 2: Activity Feed with Polymorphic Associations

```ruby
# app/models/activity.rb
class Activity < ApplicationRecord
  belongs_to :subject, polymorphic: true # CardMoved, CommentAdded, etc.
  belongs_to :account
  belongs_to :creator, class_name: "User", optional: true
  belongs_to :board, optional: true
  belongs_to :project, optional: true

  scope :recent, -> { order(created_at: :desc).limit(50) }
  scope :for_board, ->(board) { where(board: board) }
  scope :for_project, ->(project) { where(project: project) }
  scope :for_account, ->(account) { where(account: account) }
  scope :by_creator, ->(creator) { where(creator: creator) }

  # Eager load all possible subject types
  scope :with_subjects, -> {
    includes(:subject, :creator, :board, :project)
  }

  def icon
    case subject
    when CardMoved then "arrow-right"
    when CommentAdded then "message-square"
    when MemberInvited then "user-plus"
    when ProjectArchived then "archive"
    else "activity"
    end
  end

  def description
    subject.description
  end

  def actionable?
    subject.respond_to?(:url)
  end

  def url
    subject.url if actionable?
  end
end

# db/migrate/xxx_create_activities.rb
class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities, id: :uuid do |t|
      t.references :subject, polymorphic: true, null: false, type: :uuid
      t.references :account, null: false, type: :uuid
      t.references :creator, null: true, type: :uuid, foreign_key: { to_table: :users }
      t.references :board, null: true, type: :uuid
      t.references :project, null: true, type: :uuid

      t.timestamps
    end

    add_index :activities, [:account_id, :created_at]
    add_index :activities, [:board_id, :created_at]
    add_index :activities, [:project_id, :created_at]
    add_index :activities, [:creator_id, :created_at]
  end
end
```

Activity feed controller and views:

```ruby
# app/controllers/activities_controller.rb
class ActivitiesController < ApplicationController
  before_action :set_scope

  def index
    @activities = @scope.activities
      .with_subjects
      .recent
      .page(params[:page])
  end

  private

  def set_scope
    if params[:board_id]
      @scope = Current.account.boards.find(params[:board_id])
    elsif params[:project_id]
      @scope = Current.account.projects.find(params[:project_id])
    else
      @scope = Current.account
    end
  end
end
```

```erb
<!-- app/views/activities/index.html.erb -->
<div id="activities" class="space-y-4">
  <%= turbo_stream_from @scope, "activities" %>

  <% @activities.each do |activity| %>
    <%= render "activities/activity", activity: activity %>
  <% end %>
</div>

<!-- app/views/activities/_activity.html.erb -->
<div id="<%= dom_id(activity) %>" class="activity">
  <div class="flex items-start gap-3">
    <%= icon activity.icon, class: "w-5 h-5 text-gray-400" %>

    <div class="flex-1">
      <p class="text-sm">
        <%= activity.description %>
      </p>

      <p class="text-xs text-gray-500 mt-1">
        <%= time_ago_in_words(activity.created_at) %> ago
      </p>

      <% if activity.actionable? %>
        <%= link_to "View →", activity.url, class: "text-xs text-blue-600 hover:text-blue-800" %>
      <% end %>
    </div>
  </div>
</div>
```

### Pattern 3: Webhook System

```ruby
# app/models/webhook_endpoint.rb
class WebhookEndpoint < ApplicationRecord
  belongs_to :account

  has_many :webhook_deliveries, dependent: :destroy

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :events, presence: true

  serialize :events, coder: JSON

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event_type) {
    active.where("events @> ?", [event_type].to_json)
  }

  def deliver(event_type, event)
    return unless active? && subscribed_to?(event_type)

    WebhookDeliveryJob.perform_later(self, event_type, event)
  end

  def subscribed_to?(event_type)
    events.include?(event_type) || events.include?("*")
  end
end

# app/models/webhook_delivery.rb
class WebhookDelivery < ApplicationRecord
  belongs_to :webhook_endpoint
  belongs_to :event, polymorphic: true # CardMoved, CommentAdded, etc.
  belongs_to :account

  enum :status, { pending: 0, delivered: 1, failed: 2, retrying: 3 }

  validates :event_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: :pending) }
  scope :failed, -> { where(status: :failed) }

  def deliver
    response = HTTP.timeout(10).post(
      webhook_endpoint.url,
      json: payload,
      headers: headers
    )

    if response.status.success?
      delivered!
      update!(
        response_code: response.code,
        response_body: response.body.to_s,
        delivered_at: Time.current
      )
    else
      failed!
      update!(
        response_code: response.code,
        response_body: response.body.to_s,
        error_message: "HTTP #{response.code}"
      )
    end
  rescue => error
    failed!
    update!(error_message: error.message)
  end

  def payload
    {
      id: id,
      event: event_type,
      created_at: created_at.iso8601,
      data: event.as_json(
        include: event_includes,
        methods: event_methods
      )
    }
  end

  def headers
    {
      "Content-Type" => "application/json",
      "X-Webhook-ID" => id,
      "X-Webhook-Event" => event_type,
      "X-Webhook-Signature" => signature
    }
  end

  def signature
    OpenSSL::HMAC.hexdigest(
      "SHA256",
      webhook_endpoint.secret,
      payload.to_json
    )
  end

  private

  def event_includes
    case event
    when CardMoved then [:card, :from_column, :to_column, :creator]
    when CommentAdded then [:comment, :card, :creator]
    when MemberInvited then [:membership, :inviter, :invitee]
    else []
    end
  end

  def event_methods
    [:description]
  end
end

# app/jobs/webhook_delivery_job.rb
class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(event_type, event)
    webhook_endpoints = WebhookEndpoint.for_event(event_type)

    webhook_endpoints.each do |endpoint|
      delivery = WebhookDelivery.create!(
        webhook_endpoint: endpoint,
        event: event,
        event_type: event_type,
        account: event.account,
        status: :pending
      )

      delivery.deliver
    end
  end
end
```

### Pattern 4: Client-Side Event Tracking

```ruby
# app/models/tracking_event.rb
class TrackingEvent < ApplicationRecord
  belongs_to :trackable, polymorphic: true, optional: true
  belongs_to :account
  belongs_to :user, optional: true

  enum :event_type, {
    page_view: 0,
    link_click: 1,
    form_submit: 2,
    button_click: 3,
    search: 4,
    export: 5
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :of_type, ->(type) { where(event_type: type) }

  def self.track(event_type, attributes = {})
    create!(
      event_type: event_type,
      account: Current.account,
      user: Current.user,
      **attributes
    )
  end
end

# db/migrate/xxx_create_tracking_events.rb
class CreateTrackingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :tracking_events, id: :uuid do |t|
      t.references :trackable, polymorphic: true, null: true, type: :uuid
      t.references :account, null: false, type: :uuid
      t.references :user, null: true, type: :uuid
      t.integer :event_type, null: false
      t.jsonb :metadata, default: {}
      t.string :url
      t.string :referrer

      t.timestamps
    end

    add_index :tracking_events, [:account_id, :event_type, :created_at]
    add_index :tracking_events, [:user_id, :created_at]
    add_index :tracking_events, [:trackable_type, :trackable_id]
  end
end
```

### Pattern 5: Audit Trail with Event Sourcing

```ruby
# app/models/card_updated.rb
class CardUpdated < ApplicationRecord
  belongs_to :card
  belongs_to :updater, class_name: "User"
  belongs_to :account

  # Store what changed
  serialize :changes, coder: JSON

  validates :changes, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_card, ->(card) { where(card: card) }
  scope :by_attribute, ->(attribute) {
    where("changes ? :attribute", attribute: attribute)
  }

  def changed_attributes
    changes.keys
  end

  def old_value(attribute)
    changes.dig(attribute, 0)
  end

  def new_value(attribute)
    changes.dig(attribute, 1)
  end

  def description
    changed_attributes.map { |attr|
      "#{attr}: #{old_value(attr)} → #{new_value(attr)}"
    }.join(", ")
  end
end

# app/models/card.rb
class Card < ApplicationRecord
  has_many :card_updateds, dependent: :destroy

  after_update :record_update_event

  private

  def record_update_event
    return unless saved_changes.any?

    CardUpdated.create!(
      card: self,
      updater: Current.user,
      account: account,
      changes: saved_changes
    )
  end
end
```

## Commands

```bash
# Generate domain event model
rails generate model CardMoved card:references from_column:references to_column:references creator:references account:references

# Generate activity model (polymorphic)
rails generate model Activity subject:references{polymorphic} account:references creator:references

# Generate webhook models
rails generate model WebhookEndpoint url:string account:references events:text
rails generate model WebhookDelivery webhook_endpoint:references event:references{polymorphic} account:references

# Generate tracking event model
rails generate model TrackingEvent trackable:references{polymorphic} event_type:integer metadata:jsonb account:references

# Generate event processing job
rails generate job WebhookDelivery
rails generate job EventProcessor
```

## Testing

```ruby
# test/models/card_moved_test.rb
require "test_helper"

class CardMovedTest < ActiveSupport::TestCase
  test "creates activity record after creation" do
    card = cards(:one)
    from_column = columns(:todo)
    to_column = columns(:in_progress)

    assert_difference "Activity.count", 1 do
      CardMoved.create!(
        card: card,
        from_column: from_column,
        to_column: to_column,
        creator: users(:alice),
        account: accounts(:acme)
      )
    end
  end

  test "enqueues webhook delivery job" do
    assert_enqueued_with(job: WebhookDeliveryJob) do
      CardMoved.create!(
        card: cards(:one),
        from_column: columns(:todo),
        to_column: columns(:in_progress),
        creator: users(:alice),
        account: accounts(:acme)
      )
    end
  end

  test "description includes card and columns" do
    moved = card_moveds(:one)

    assert_includes moved.description, moved.card.title
    assert_includes moved.description, moved.from_column.name
    assert_includes moved.description, moved.to_column.name
  end
end

# test/models/webhook_delivery_test.rb
require "test_helper"

class WebhookDeliveryTest < ActiveSupport::TestCase
  test "deliver sends POST request to webhook URL" do
    delivery = webhook_deliveries(:pending)

    stub_request(:post, delivery.webhook_endpoint.url)
      .to_return(status: 200, body: "OK")

    delivery.deliver

    assert delivery.delivered?
    assert_equal 200, delivery.response_code
  end

  test "deliver marks as failed on error" do
    delivery = webhook_deliveries(:pending)

    stub_request(:post, delivery.webhook_endpoint.url)
      .to_return(status: 500, body: "Error")

    delivery.deliver

    assert delivery.failed?
    assert_equal 500, delivery.response_code
  end
end
```

## Boundaries

### Always Do:
- Create domain-specific event models (CardMoved, not Event with type: "card.moved")
- Use polymorphic associations for activities and webhook deliveries
- Scope all events to account_id
- Use UUIDs for event IDs
- Store metadata as JSONB for flexibility
- Use background jobs for webhook delivery
- Include signature/authentication for webhooks
- Create activities from events for user-facing feeds
- Index by account_id and created_at
- Use Solid Queue for event processing (no Redis/Kafka)

### Ask First:
- External event bus/streaming (prefer database events)
- Real-time delivery requirements (vs. async background jobs)
- Event replay/reprocessing capabilities
- Long-term event retention policies
- Event schema versioning strategies
- Webhook retry policies beyond defaults

### Never Do:
- Generic event tables with type strings and JSON blobs
- Boolean tracking fields instead of event records
- Synchronous webhook delivery
- External message queues (Redis, RabbitMQ, Kafka) - use Solid Queue
- Service objects for event handling - put logic in models
- Foreign key constraints on polymorphic associations
- Exposing internal IDs in webhook payloads (use UUIDs)
- Webhooks without authentication/signatures
- Storing full request/response bodies without size limits
