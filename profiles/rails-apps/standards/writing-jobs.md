---
name: writing-jobs
description: Creates idempotent Solid Queue background jobs with _later/_now conventions when processing work asynchronously
---

You are an expert in creating performant, idempotent background jobs for Rails applications using Solid Queue.

## Quick Start

Generate a job and use the _later/_now convention to keep business logic in models:

```bash
bin/rails generate job NotifyRecipients
```

```ruby
# app/jobs/notify_recipients_job.rb
class NotifyRecipientsJob < ApplicationJob
  queue_as :default

  def perform(notifiable)
    notifiable.notify_recipients_now
  end
end

# app/models/concerns/notifiable.rb
module Notifiable
  def notify_recipients_later
    NotifyRecipientsJob.perform_later(self)
  end

  def notify_recipients_now
    # Business logic stays here
    recipients.each { |recipient| send_notification(recipient) }
  end
end
```

## Core Principles

**Jobs orchestrate. Models do the work.**

1. **Thin Jobs** - Jobs should be simple wrappers that call model methods
2. **_later/_now Convention** - Explicit async/sync pairs make testing easier
3. **Idempotency** - Jobs can be executed multiple times safely
4. **Solid Queue** - Database-backed (no Redis), transactions work across jobs/data
5. **Pass IDs, Not Objects** - Serialize IDs, not full ActiveRecord objects

## Patterns

### Pattern 1: Simple Notification Job

```ruby
# app/jobs/notify_recipients_job.rb
class NotifyRecipientsJob < ApplicationJob
  queue_as :default

  def perform(notifiable)
    notifiable.notify_recipients_now
  end
end

# app/models/concerns/notifiable.rb
module Notifiable
  extend ActiveSupport::Concern

  def notify_recipients_later
    NotifyRecipientsJob.perform_later(self)
  end

  def notify_recipients_now
    recipients.each do |recipient|
      next if recipient == creator

      Notification.create!(
        recipient: recipient,
        notifiable: self,
        action: notification_action
      )
    end
  end

  def notify_recipients
    notify_recipients_now # Default to sync
  end

  private

  def recipients
    []
  end

  def notification_action
    "#{self.class.name.underscore}_created"
  end
end

# Usage in model
class Comment < ApplicationRecord
  include Notifiable

  after_create_commit :notify_recipients_later

  private

  def recipients
    card.watchers + card.assignees + [card.creator]
  end
end
```

### Pattern 2: Batch Processing Job

```ruby
# app/jobs/deliver_bundled_notifications_job.rb
class DeliverBundledNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    Notification::Bundle.deliver_all_now
  end
end

# app/models/notification/bundle.rb
class Notification::Bundle
  def self.deliver_all_later
    DeliverBundledNotificationsJob.perform_later
  end

  def self.deliver_all_now
    User.find_each do |user|
      bundle = new(user)
      bundle.deliver if bundle.has_notifications?
    end
  end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def has_notifications?
    unread_notifications.any?
  end

  def deliver
    NotificationMailer.bundled(user, unread_notifications).deliver_now
    mark_as_bundled
  end

  private

  def unread_notifications
    @unread_notifications ||= user.notifications.unread
      .where("created_at > ?", 30.minutes.ago)
  end

  def mark_as_bundled
    unread_notifications.update_all(bundled_at: Time.current)
  end
end
```

### Pattern 3: Idempotent Job with Guard Clauses

```ruby
# app/jobs/calculate_metrics_job.rb
class CalculateMetricsJob < ApplicationJob
  queue_as :default

  def perform(entity_id)
    entity = Entity.find_by(id: entity_id)
    return unless entity # Idempotent: ignore if deleted

    log_job_execution("Calculating metrics for entity ##{entity_id}")

    average_score = entity.submissions.average(:rating).to_f.round(1)
    submissions_count = entity.submissions.count

    entity.update!(
      average_score: average_score,
      submissions_count: submissions_count
    )

    log_job_execution("Metrics updated: #{average_score} (#{submissions_count} submissions)")
  end

  private

  def log_job_execution(message)
    Rails.logger.info("[#{self.class.name}] #{message}")
  end
end
```

### Pattern 4: Job with Retry Strategies

```ruby
# app/jobs/dispatch_webhook_job.rb
class DispatchWebhookJob < ApplicationJob
  queue_as :webhooks
  retry_on StandardError, wait: :exponentially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(webhook, event)
    webhook.dispatch_now(event)
  end
end

# app/models/webhook.rb
class Webhook < ApplicationRecord
  def dispatch_later(event)
    DispatchWebhookJob.perform_later(self, event)
  end

  def dispatch_now(event)
    response = HTTP.post(url, json: event.to_webhook_payload)

    if response.status.success?
      increment!(:successful_deliveries)
    else
      increment!(:failed_deliveries)
      raise "Webhook delivery failed: #{response.status}"
    end
  end
end
```

### Pattern 5: Progress Tracking Job

```ruby
# app/jobs/export_data_job.rb
class ExportDataJob < ApplicationJob
  queue_as :exports

  def perform(user_id, export_type)
    user = User.find(user_id)
    export = user.exports.create!(export_type: export_type, status: :processing)

    begin
      total_records = count_records(user, export_type)
      processed = 0

      csv_data = CSV.generate do |csv|
        csv << headers_for(export_type)

        records_for(user, export_type).find_each do |record|
          csv << data_for(record, export_type)
          processed += 1

          # Update progress every 100 records
          if processed % 100 == 0
            progress = (processed.to_f / total_records * 100).round(2)
            export.update!(progress: progress)
          end
        end
      end

      export.file.attach(
        io: StringIO.new(csv_data),
        filename: "export_#{export_type}_#{Date.current}.csv",
        content_type: "text/csv"
      )

      export.update!(status: :completed, completed_at: Time.current, progress: 100)
      ExportMailer.ready(export).deliver_later

      log_job_execution("Export completed: #{processed} records")
    rescue StandardError => e
      export.update!(status: :failed, error_message: e.message)
      raise
    end
  end

  private

  def count_records(user, export_type)
    records_for(user, export_type).count
  end

  def records_for(user, export_type)
    case export_type
    when "entities" then user.entities
    when "submissions" then user.submissions
    else raise ArgumentError, "Unknown export type: #{export_type}"
    end
  end

  def headers_for(export_type)
    case export_type
    when "entities" then ["ID", "Name", "Address", "Phone", "Created At"]
    when "submissions" then ["ID", "Entity", "Rating", "Content", "Date"]
    end
  end

  def data_for(record, export_type)
    case export_type
    when "entities" then [record.id, record.name, record.address, record.phone, record.created_at]
    when "submissions" then [record.id, record.entity.name, record.rating, record.content, record.created_at]
    end
  end

  def log_job_execution(message)
    Rails.logger.info("[#{self.class.name}] #{message}")
  end
end
```

## Commands

```bash
# Generate job
bin/rails generate job NotifyRecipients

# Run worker (development)
bundle exec rake solid_queue:start

# Check queue
bin/rails runner "puts SolidQueue::Job.count"

# Clear jobs
bin/rails runner "SolidQueue::Job.destroy_all"

# Cache stats
rails solid_queue:stats

# All job tests
bundle exec rspec spec/jobs/

# Specific job test
bundle exec rspec spec/jobs/calculate_metrics_job_spec.rb
```

## Recurring Jobs

Configure recurring jobs in `config/recurring.yml`:

```yaml
production:
  # Bundle and send notifications every 30 minutes
  deliver_bundled_notifications:
    command: "Notification::Bundle.deliver_all_later"
    schedule: every 30 minutes

  # Cleanup old sessions daily at 3am
  cleanup_old_sessions:
    command: "Session.cleanup_old_sessions_later"
    schedule: every day at 3am

  # Weekly digest (Sundays at 9am)
  weekly_digest:
    command: "Digest.send_weekly_later"
    schedule: every sunday at 9am

development:
  # Same jobs, but more frequent for testing
  deliver_bundled_notifications:
    command: "Notification::Bundle.deliver_all_later"
    schedule: every 5 minutes
```

## Queue Configuration

Configure multiple queues in `config/solid_queue.yml`:

```yaml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500

  workers:
    - queues: default
      threads: 3
      processes: 2
      polling_interval: 0.1

    - queues: mailers,notifications
      threads: 5
      processes: 1
      polling_interval: 0.1

    - queues: imports,exports
      threads: 2
      processes: 1
      polling_interval: 1

    - queues: maintenance
      threads: 1
      processes: 1
      polling_interval: 5

development:
  workers:
    - queues: "*"
      threads: 3
      processes: 1
      polling_interval: 1
```

## Testing

### Test Model Methods Directly

```ruby
# spec/models/comment_spec.rb
RSpec.describe Comment, type: :model do
  describe "#notify_recipients_now" do
    let(:comment) { create(:comment) }

    it "creates notifications" do
      expect {
        comment.notify_recipients_now
      }.to change(Notification, :count).by(2)
    end

    it "doesn't notify comment creator" do
      comment.notify_recipients_now

      expect(Notification.exists?(
        recipient_id: comment.creator_id,
        notifiable: comment
      )).to be false
    end
  end
end
```

### Test Job Enqueuing

```ruby
# spec/jobs/notify_recipients_job_spec.rb
require "rails_helper"

RSpec.describe NotifyRecipientsJob, type: :job do
  describe "#perform" do
    let(:comment) { create(:comment) }

    it "calls notify_recipients_now" do
      expect {
        described_class.perform_now(comment)
      }.to change(Notification, :count).by(2)
    end
  end

  describe "enqueue" do
    it "uses the correct queue" do
      expect(described_class.new.queue_name).to eq("default")
    end

    it "can be enqueued" do
      expect {
        described_class.perform_later(create(:comment))
      }.to have_enqueued_job(described_class)
        .on_queue("default")
    end
  end
end
```

## Boundaries

### Always Do:
- Keep jobs thin (call model methods)
- Use _later/_now naming convention
- Put business logic in models
- Make jobs idempotent (can run multiple times safely)
- Pass IDs instead of ActiveRecord objects when possible
- Set queue priorities based on importance
- Implement retry strategies for unreliable operations
- Test model methods directly (not just jobs)
- Use Solid Queue (database-backed)
- Handle errors gracefully
- Log job performance
- Use recurring jobs for scheduled tasks

### Ask First:
- Before putting business logic in jobs (belongs in models)
- Before using Redis/Sidekiq (use Solid Queue)
- Before creating custom queue backends
- Before bypassing retry mechanisms
- Before running jobs synchronously in production

### Never Do:
- Put business logic in jobs (use models)
- Use Sidekiq/Resque (use Solid Queue - database-backed)
- Forget to handle errors
- Skip retry strategies for unreliable operations
- Enqueue jobs inside transactions (may not commit)
- Pass unsupported argument types
- Forget to test jobs
- Run expensive operations synchronously
- Forget Current.reset in jobs with context
- Skip monitoring job queues
- Assume jobs run in order
- Create jobs without considering idempotency
