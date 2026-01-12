---
name: writing-mailers
description: Creates minimal ActionMailer emails with bundled notifications when sending transactional emails to users
---

You are an expert in creating minimal, effective mailers for Rails applications using ActionMailer.

## Quick Start

Generate a mailer and create both text and HTML templates:

```bash
rails generate mailer Comment mentioned
```

```ruby
# app/mailers/comment_mailer.rb
class CommentMailer < ApplicationMailer
  def mentioned(mention)
    @mention = mention
    @comment = mention.comment
    @card = mention.comment.card

    mail(
      to: mention.user.email,
      subject: "#{mention.creator.name} mentioned you in #{@card.title}"
    )
  end
end
```

```erb
<!-- app/views/comment_mailer/mentioned.text.erb -->
Hi <%= @mention.user.name %>,

<%= @mention.creator.name %> mentioned you in a comment on <%= @card.title %>:

"<%= @comment.body %>"

View the card: <%= card_url(@card) %>

---
You're receiving this because you were mentioned.
```

## Core Principles

**Minimal Mailers, Bundled Notifications**

1. **Plain-text First** - Create both text and HTML versions, but text is primary
2. **Bundle Notifications** - Send one digest email instead of many individual emails
3. **Transactional Only** - No marketing campaigns, only transactional emails
4. **deliver_later** - Always use background delivery in production
5. **Email Previews** - Create previews for development testing
6. **Inline CSS** - No external stylesheets for HTML emails
7. **Respect Preferences** - Check user email preferences before sending

## Patterns

### Pattern 1: Simple Transactional Mailer

```ruby
# app/mailers/application_mailer.rb
class ApplicationMailer < ActionMailer::Base
  default from: "notifications@example.com"
  layout "mailer"

  # Add account context to from address
  def account_from_address(account)
    "#{account.name} <notifications@example.com>"
  end

  # Set Reply-To for account emails
  def account_reply_to(account)
    "#{account.slug}@reply.example.com"
  end

  private

  def default_url_options
    { host: Rails.application.config.action_mailer.default_url_options[:host] }
  end
end

# app/mailers/comment_mailer.rb
class CommentMailer < ApplicationMailer
  def mentioned(mention)
    @mention = mention
    @comment = mention.comment
    @card = mention.comment.card
    @account = mention.account

    mail(
      to: mention.user.email,
      subject: "#{mention.creator.name} mentioned you in #{@card.title}",
      from: account_from_address(@account),
      reply_to: account_reply_to(@account)
    )
  end

  def new_comment(comment, recipient)
    @comment = comment
    @card = comment.card
    @account = comment.account
    @recipient = recipient

    mail(
      to: recipient.email,
      subject: "New comment on #{@card.title}",
      from: account_from_address(@account)
    )
  end
end

# app/mailers/membership_mailer.rb
class MembershipMailer < ApplicationMailer
  def invitation(membership)
    @membership = membership
    @account = membership.account
    @inviter = membership.inviter

    mail(
      to: membership.user.email,
      subject: "#{@inviter.name} invited you to #{@account.name}",
      from: account_from_address(@account)
    )
  end

  def removed(membership)
    @membership = membership
    @account = membership.account

    mail(
      to: membership.user.email,
      subject: "You've been removed from #{@account.name}"
    )
  end
end
```

### Pattern 2: Email Templates

```erb
<!-- app/views/comment_mailer/mentioned.text.erb -->
Hi <%= @mention.user.name %>,

<%= @mention.creator.name %> mentioned you in a comment on <%= @card.title %>:

"<%= @comment.body %>"

View the card: <%= account_board_card_url(@account, @card.board, @card) %>

---
You're receiving this because you were mentioned.

<!-- app/views/comment_mailer/mentioned.html.erb -->
<p>Hi <%= @mention.user.name %>,</p>

<p><%= @mention.creator.name %> mentioned you in a comment on <strong><%= @card.title %></strong>:</p>

<blockquote style="border-left: 3px solid #ccc; padding-left: 15px; color: #666;">
  <%= simple_format(@comment.body) %>
</blockquote>

<p>
  <%= link_to "View the card", account_board_card_url(@account, @card.board, @card),
      style: "color: #0066cc; text-decoration: none;" %>
</p>

<p style="color: #999; font-size: 12px; margin-top: 30px;">
  You're receiving this because you were mentioned.
</p>
```

### Pattern 3: Minimal Email Layouts

```erb
<!-- app/views/layouts/mailer.text.erb -->
<%= yield %>

---
<%= @account&.name || "Example App" %>
<%= root_url %>

<!-- app/views/layouts/mailer.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      body {
        margin: 0;
        padding: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        font-size: 16px;
        line-height: 1.5;
        color: #333;
        background-color: #f5f5f5;
      }

      table {
        border-collapse: collapse;
      }

      a {
        color: #0066cc;
      }

      .email-container {
        width: 100%;
        max-width: 600px;
        margin: 0 auto;
      }

      .email-content {
        background-color: white;
        padding: 40px 30px;
      }

      .email-footer {
        padding: 20px 30px;
        text-align: center;
        color: #999;
        font-size: 12px;
      }
    </style>
  </head>
  <body>
    <table class="email-container" role="presentation">
      <tr>
        <td class="email-content">
          <%= yield %>
        </td>
      </tr>
      <tr>
        <td class="email-footer">
          <%= @account&.name || "Example App" %><br>
          <%= link_to root_url, root_url %>
        </td>
      </tr>
    </table>
  </body>
</html>
```

### Pattern 4: Bundled Notifications (Digest Emails)

```ruby
# app/mailers/digest_mailer.rb
class DigestMailer < ApplicationMailer
  def daily_activity(user, account, activities)
    @user = user
    @account = account
    @activities = activities
    @grouped_activities = activities.group_by(&:subject_type)

    mail(
      to: user.email,
      subject: "Daily activity summary for #{account.name}",
      from: account_from_address(account)
    )
  end

  def pending_notifications(user, notifications)
    @user = user
    @notifications = notifications
    @accounts = notifications.map(&:account).uniq

    mail(
      to: user.email,
      subject: "You have #{notifications.size} pending notifications"
    )
  end
end

# app/models/notification_bundler.rb
class NotificationBundler
  def initialize(user)
    @user = user
  end

  def pending_notifications
    @user.notifications
      .where(sent_at: nil)
      .where("created_at > ?", 1.hour.ago)
      .order(created_at: :desc)
  end

  def should_send_digest?
    pending_notifications.count >= 5 || oldest_pending_notification_age > 1.hour
  end

  def send_digest
    return unless should_send_digest?

    notifications = pending_notifications

    DigestMailer.pending_notifications(@user, notifications).deliver_later

    notifications.update_all(sent_at: Time.current)
  end

  private

  def oldest_pending_notification_age
    oldest = pending_notifications.order(created_at: :asc).first
    oldest ? Time.current - oldest.created_at : 0
  end
end

# app/jobs/send_digest_emails_job.rb
class SendDigestEmailsJob < ApplicationJob
  queue_as :mailers

  def perform(frequency: :daily)
    User.where(digest_frequency: frequency).find_each do |user|
      user.accounts.each do |account|
        activities = user.activities_for_digest(account, frequency)

        if activities.any?
          DigestMailer.daily_activity(user, account, activities).deliver_now
        end
      end
    end
  end
end
```

```erb
<!-- app/views/digest_mailer/daily_activity.text.erb -->
Hi <%= @user.name %>,

Here's what happened today in <%= @account.name %>:

<% @grouped_activities.each do |type, activities| %>
<%= type.pluralize %> (<%= activities.size %>):
<% activities.first(5).each do |activity| %>
  - <%= activity.description %>
<% end %>
<% if activities.size > 5 %>
  ... and <%= activities.size - 5 %> more
<% end %>

<% end %>

View all activity: <%= account_activities_url(@account) %>

---
You're receiving this because you opted in to daily digests.
Manage preferences: <%= account_settings_url(@account) %>
```

### Pattern 5: Email Preferences

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :email_preferences, dependent: :destroy

  enum :digest_frequency, {
    never: 0,
    daily: 1,
    weekly: 2
  }, prefix: true

  def wants_email?(account, type)
    preference = email_preferences.find_by(account: account, preference_type: type)
    preference.nil? || preference.enabled?
  end
end

# app/models/email_preference.rb
class EmailPreference < ApplicationRecord
  belongs_to :user
  belongs_to :account

  enum :preference_type, {
    mentions: 0,
    comments: 1,
    assignments: 2,
    digests: 3
  }

  validates :preference_type, presence: true
  validates :preference_type, uniqueness: { scope: [:user_id, :account_id] }
end

# app/models/comment.rb
class Comment < ApplicationRecord
  after_create_commit :notify_subscribers

  private

  def notify_subscribers
    card.subscribers.each do |subscriber|
      next if subscriber == creator
      next unless subscriber.wants_email?(account, :comments)

      CommentMailer.new_comment(self, subscriber).deliver_later
    end
  end
end
```

### Pattern 6: Email Previews

```ruby
# spec/mailers/previews/comment_mailer_preview.rb
class CommentMailerPreview < ActionMailer::Preview
  # Preview at: http://localhost:3000/rails/mailers/comment_mailer/mentioned
  def mentioned
    mention = Mention.first || create_sample_mention
    CommentMailer.mentioned(mention)
  end

  private

  def create_sample_mention
    user = User.first || User.create!(name: "Alice", email: "alice@example.com")
    # ... create account, board, card, comment
    Mention.create!(user: user, comment: comment, creator: user, account: account)
  end
end
```

## Commands

```bash
# Generate mailer
rails generate mailer Comment mentioned

# Generate mailer with methods
rails generate mailer Digest daily_activity weekly_summary

# Preview emails in development
# Visit http://localhost:3000/rails/mailers

# Test email delivery in console
CommentMailer.mentioned(mention).deliver_now

# Background delivery
CommentMailer.mentioned(mention).deliver_later

# Generate preview
rails generate mailer_preview Comment

# All mailer tests
bundle exec rspec spec/mailers/

# Specific mailer test
bundle exec rspec spec/mailers/entity_mailer_spec.rb
```

## Testing

```ruby
# spec/mailers/comment_mailer_spec.rb
require "rails_helper"

RSpec.describe CommentMailer, type: :mailer do
  describe "#mentioned" do
    let(:mention) { create(:mention) }
    let(:mail) { described_class.mentioned(mention) }

    it "sends email to the mentioned user" do
      expect(mail.to).to eq([mention.user.email])
    end

    it "has the correct subject" do
      expect(mail.subject).to include(mention.creator.name)
    end

    it "has both HTML and text versions" do
      expect(mail.html_part.body.encoded).to include("<p>")
      expect(mail.text_part.body.encoded).not_to include("<")
    end
  end
end
```

## Boundaries

### Always Do:
- Use `deliver_later` for background delivery
- Create both text and HTML versions of emails
- Use inline CSS for HTML emails (no external stylesheets)
- Include unsubscribe links in all emails
- Respect user email preferences
- Use email previews for development
- Bundle notifications to reduce email fatigue
- Use simple, minimal layouts
- Include account context in from/reply-to addresses
- Test email delivery and content

### Ask First:
- Whether to bundle notifications vs. send immediately
- Digest frequency (daily, weekly, never)
- Whether to include attachments
- Complex HTML email designs
- Marketing emails (should be separate from transactional)
- Email service providers (SendGrid, Postmark, etc.)

### Never Do:
- Send marketing emails from transactional mailers
- Use complex HTML frameworks (no Foundation Email, MJML)
- Deliver synchronously in production (`deliver_now`)
- Send emails without checking user preferences
- Forget unsubscribe links
- Use external CSS files
- Send one email per event (bundle when possible)
- Expose sensitive data in email URLs
- Forget to set default_url_options
- Use generic from addresses (use account context)
- Hardcode email addresses
- Send emails without tests
- Skip email previews
