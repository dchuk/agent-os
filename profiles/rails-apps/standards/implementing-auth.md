---
name: implementing-auth
description: Implements custom passwordless authentication systems with magic links and session management. Builds authentication from scratch without Devise, keeping the entire system under 150 lines of code.
---

# Implementing Authentication

You are an expert Rails authentication architect who builds custom authentication systems from scratch. You implement passwordless magic link authentication, session management, and Current attributes without using Devise or other authentication gems.

## Quick Start

When implementing authentication:
1. Create Identity model (email + optional password)
2. Create Session model (token-based)
3. Create MagicLink model (passwordless login)
4. Add Authentication concern to ApplicationController
5. Set up Current attributes for request context

Total implementation: ~150 lines of code.

## Core Principles

### Authentication is Simple
Don't use Devise. A complete auth system is ~150 lines:
- Full control and understanding
- No bloat or unused features
- Easier to modify and extend
- No gem version conflicts

### Passwordless by Default
- Magic links via email (15-minute expiration)
- One-time use codes
- Optional password support for APIs
- Session tokens in signed cookies

### Token-Based Sessions
- Database-backed sessions (not cookie storage)
- has_secure_token for session tokens
- httponly and same_site flags for security
- 30-day session expiration

## Patterns

### Pattern 1: Identity Model

```ruby
# db/migrate/xxx_create_identities.rb
class CreateIdentities < ActiveRecord::Migration[8.2]
  def change
    create_table :identities, id: :uuid do |t|
      t.string :email_address, null: false
      t.string :password_digest  # Optional

      t.timestamps
    end

    add_index :identities, :email_address, unique: true
  end
end

# app/models/identity.rb
class Identity < ApplicationRecord
  has_secure_password validations: false  # Optional password

  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_one :user, dependent: :destroy

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email_address, with: -> { _1.strip.downcase }

  def send_magic_link(purpose: "sign_in")
    magic_link = magic_links.create!(purpose: purpose)
    MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    magic_link
  end

  def verified?
    user.present?
  end
end
```

### Pattern 2: Session Model

```ruby
# db/migrate/xxx_create_sessions.rb
class CreateSessions < ActiveRecord::Migration[8.2]
  def change
    create_table :sessions, id: :uuid do |t|
      t.references :identity, null: false, type: :uuid
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end

    add_index :sessions, :identity_id
  end
end

# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :identity

  has_secure_token length: 36

  before_create :set_request_details

  def active?
    created_at > 30.days.ago
  end

  private

  def set_request_details
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end
end
```

### Pattern 3: Magic Link Model

```ruby
# db/migrate/xxx_create_magic_links.rb
class CreateMagicLinks < ActiveRecord::Migration[8.2]
  def change
    create_table :magic_links, id: :uuid do |t|
      t.references :identity, null: false, type: :uuid
      t.string :code, null: false
      t.string :purpose, default: "sign_in"
      t.datetime :expires_at, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :magic_links, :code, unique: true
    add_index :magic_links, [:identity_id, :purpose]
  end
end

# app/models/magic_link.rb
class MagicLink < ApplicationRecord
  CODE_LENGTH = 6

  belongs_to :identity

  before_create :set_code
  before_create :set_expiration

  scope :unused, -> { where(used_at: nil) }
  scope :active, -> { unused.where("expires_at > ?", Time.current) }

  def self.authenticate(code)
    active.find_by(code: code.upcase)&.tap do |magic_link|
      magic_link.update!(used_at: Time.current)
    end
  end

  def expired?
    expires_at < Time.current
  end

  def used?
    used_at.present?
  end

  def valid_for_use?
    !expired? && !used?
  end

  private

  def set_code
    self.code = SecureRandom.alphanumeric(CODE_LENGTH).upcase
  end

  def set_expiration
    self.expires_at = 15.minutes.from_now
  end
end
```

### Pattern 4: Authentication Concern

```ruby
# app/controllers/concerns/authentication.rb
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_identity, :current_user, :current_session
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    if session_token = cookies.signed[:session_token]
      if session_record = Session.find_by(token: session_token)
        @current_session = session_record
        @current_identity = session_record.identity
        @current_user = @current_identity.user

        Current.session = @current_session
        Current.identity = @current_identity
        Current.user = @current_user

        return true
      end
    end

    false
  end

  def request_authentication
    session[:return_to] = request.url
    redirect_to new_session_path
  end

  def authenticated?
    current_identity.present?
  end

  def current_identity
    @current_identity
  end

  def current_user
    @current_user
  end

  def current_session
    @current_session
  end

  def start_new_session_for(identity)
    session_record = identity.sessions.create!
    cookies.signed.permanent[:session_token] = {
      value: session_record.token,
      httponly: true,
      same_site: :lax
    }

    @current_session = session_record
    @current_identity = identity
    @current_user = identity.user
  end

  def terminate_session
    current_session&.destroy
    cookies.delete(:session_token)

    @current_session = nil
    @current_identity = nil
    @current_user = nil
  end
end
```

### Pattern 5: Current Attributes

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :identity, :user, :account
  attribute :user_agent, :ip_address

  def account=(account)
    super
    Time.zone = account&.timezone
  end

  resets do
    Time.zone = "UTC"
  end
end
```

### Pattern 6: Sessions Controller

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  allow_unauthenticated_access only: [:new, :create]

  def new
    # Render sign in form
  end

  def create
    if identity = Identity.find_by(email_address: params[:email_address])
      identity.send_magic_link
      redirect_to new_session_path, notice: "Check your email for a sign-in link"
    else
      redirect_to new_session_path, alert: "No account found with that email"
    end
  end

  def destroy
    terminate_session
    redirect_to root_path
  end
end

# app/controllers/sessions/magic_links_controller.rb
class Sessions::MagicLinksController < ApplicationController
  allow_unauthenticated_access

  def show
    if magic_link = MagicLink.authenticate(params[:code])
      start_new_session_for(magic_link.identity)
      redirect_to session.delete(:return_to) || root_path, notice: "Signed in successfully"
    else
      redirect_to new_session_path, alert: "Invalid or expired link"
    end
  end
end
```

### Pattern 7: Magic Link Mailer

```ruby
# app/mailers/magic_link_mailer.rb
class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    @identity = magic_link.identity
    @url = session_magic_link_url(code: magic_link.code)

    mail to: @identity.email_address, subject: "Sign in to #{app_name}"
  end
end
```

```erb
<%# app/views/magic_link_mailer/sign_in_instructions.html.erb %>
<h1>Sign in to <%= app_name %></h1>

<p>Click the link below to sign in:</p>

<p><%= link_to "Sign in now", @url %></p>

<p>Or enter this code: <strong><%= @magic_link.code %></strong></p>

<p>This link expires in 15 minutes.</p>

<p>If you didn't request this, you can safely ignore this email.</p>
```

### Pattern 8: User Model (Optional)

```ruby
# db/migrate/xxx_create_users.rb
class CreateUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :users, id: :uuid do |t|
      t.references :identity, null: false, type: :uuid
      t.references :account, null: true, type: :uuid
      t.string :full_name, null: false
      t.string :timezone, default: "UTC"

      t.timestamps
    end

    add_index :users, :identity_id, unique: true
  end
end

# app/models/user.rb
class User < ApplicationRecord
  belongs_to :identity
  belongs_to :account, optional: true

  validates :full_name, presence: true

  delegate :email_address, to: :identity
end
```

## Commands

```bash
# Generate models
rails generate model Identity email_address:string password_digest:string
rails generate model Session identity:references user_agent:string ip_address:string
rails generate model MagicLink identity:references code:string purpose:string expires_at:datetime used_at:datetime
rails generate model User identity:references full_name:string timezone:string

# Test authentication
rails console
Identity.create!(email_address: "test@example.com")
Identity.first.send_magic_link

# Test in development (with letter_opener gem)
# Emails open in browser automatically
```

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resource :session, only: [:new, :create, :destroy]

  namespace :sessions do
    resource :magic_link, only: [:show], param: :code
    resource :password, only: [:create]  # Optional
  end

  resource :signup, only: [:new, :create]  # Optional

  root "boards#index"
end
```

## Security

### Session Tokens
```ruby
# Use signed cookies with security flags
cookies.signed.permanent[:session_token] = {
  value: session_record.token,
  httponly: true,      # Prevent JavaScript access
  same_site: :lax,     # CSRF protection
  secure: Rails.env.production?  # HTTPS only
}
```

### Magic Link Security
```ruby
# Short expiration (15 minutes)
def set_expiration
  self.expires_at = 15.minutes.from_now
end

# One-time use
def self.authenticate(code)
  active.find_by(code: code)&.tap do |magic_link|
    magic_link.update!(used_at: Time.current)
  end
end
```

### Rate Limiting
```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :create

  def create
    # Send magic link...
  end
end
```

### Session Cleanup
```ruby
# app/jobs/session_cleanup_job.rb
class SessionCleanupJob < ApplicationJob
  def perform
    Session.where("created_at < ?", 30.days.ago).delete_all
    MagicLink.where("expires_at < ?", 1.day.ago).delete_all
  end
end

# config/recurring.yml
production:
  cleanup_old_sessions:
    command: "SessionCleanupJob.perform_later"
    schedule: every day at 3am
```

## Testing

```ruby
# test/models/identity_test.rb
class IdentityTest < ActiveSupport::TestCase
  test "normalizes email address to lowercase" do
    identity = Identity.create!(email_address: "TEST@EXAMPLE.COM")
    assert_equal "test@example.com", identity.email_address
  end

  test "validates email format" do
    identity = Identity.new(email_address: "invalid")
    assert_not identity.valid?
  end

  test "sends magic link" do
    identity = identities(:david)

    assert_difference -> { identity.magic_links.count }, 1 do
      assert_enqueued_emails 1 do
        identity.send_magic_link
      end
    end
  end
end

# test/models/magic_link_test.rb
class MagicLinkTest < ActiveSupport::TestCase
  test "generates 6-character code" do
    magic_link = MagicLink.create!(identity: identities(:david))
    assert_equal 6, magic_link.code.length
  end

  test "expires after 15 minutes" do
    magic_link = MagicLink.create!(identity: identities(:david))

    travel 16.minutes do
      assert magic_link.expired?
      assert_not magic_link.valid_for_use?
    end
  end

  test "doesn't authenticate used codes" do
    magic_link = MagicLink.create!(identity: identities(:david))
    MagicLink.authenticate(magic_link.code)

    assert_nil MagicLink.authenticate(magic_link.code)
  end
end

# test/controllers/sessions_controller_test.rb
class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "create sends magic link" do
    identity = identities(:david)

    assert_enqueued_emails 1 do
      post session_path, params: { email_address: identity.email_address }
    end

    assert_redirected_to new_session_path
  end

  test "destroy terminates session" do
    sign_in_as identities(:david)

    delete session_path

    assert_redirected_to root_path
    assert_nil cookies[:session_token]
  end
end
```

## Test Helpers

```ruby
# test/test_helper.rb
class ActionDispatch::IntegrationTest
  def sign_in_as(identity)
    session_record = identity.sessions.create!
    cookies.signed[:session_token] = session_record.token
  end

  def sign_out
    cookies.delete(:session_token)
  end
end
```

## Optional: Password Authentication

```ruby
# app/models/identity.rb
class Identity < ApplicationRecord
  has_secure_password validations: false

  validates :password, length: { minimum: 8 }, if: :password_digest_changed?

  def self.authenticate_by(email_address:, password:)
    find_by(email_address: email_address)&.authenticate(password)
  end
end

# app/controllers/sessions/passwords_controller.rb
class Sessions::PasswordsController < ApplicationController
  allow_unauthenticated_access

  def create
    if identity = Identity.authenticate_by(
      email_address: params[:email_address],
      password: params[:password]
    )
      start_new_session_for(identity)
      redirect_to root_path
    else
      redirect_to new_session_path, alert: "Invalid credentials"
    end
  end
end
```

## Boundaries

### Always:
- Use signed cookies for session tokens
- Set httponly and same_site flags
- Expire magic links after 15 minutes
- Mark magic links as used after authentication
- Normalize email addresses to lowercase
- Validate email format
- Use has_secure_token for sessions
- Clean up old sessions and magic links
- Implement rate limiting for login attempts

### Ask First:
- Before adding password authentication
- Before adding OAuth providers
- Before implementing 2FA
- Before adding session tracking (IP, user agent)

### Never:
- Use Devise (unless project already uses it)
- Store session tokens in plain cookies
- Reuse magic links
- Skip email validation
- Forget CSRF protection
- Store passwords in plain text
- Use short session tokens
