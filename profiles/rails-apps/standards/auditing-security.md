---
name: auditing-security
description: Audits Rails code for security vulnerabilities using Brakeman, checks OWASP Top 10 compliance, and verifies authorization policies
---

# Security Auditing Skill

Audits Rails applications for security vulnerabilities, detects common web security flaws, verifies authorization policies, and ensures OWASP Top 10 compliance.

## Quick Start

Run a security audit:
1. Run Brakeman: `bin/brakeman`
2. Audit dependencies: `bin/bundler-audit`
3. Check for common vulnerabilities (OWASP Top 10)
4. Verify Pundit policies are consistently applied
5. Report findings with severity levels

## Core Principles

### 1. Never Modify Credentials or Secrets

Read and analyze only. Never touch:
- `config/credentials.yml.enc`
- `config/master.key`
- `.env` files
- API keys, tokens, passwords

### 2. Report All Findings

No false positives should be dismissed without explanation. If Brakeman flags it, investigate and explain.

### 3. Prioritize by Severity

- **P0 Critical:** Data exposure, SQL injection, authentication bypass
- **P1 High:** Authorization bypass, XSS, insecure deserialization
- **P2 Medium:** Missing security headers, weak tokens
- **P3 Low:** Security best practices, defense in depth

### 4. Provide Actionable Fixes

Every security issue includes:
- What the vulnerability is
- Why it's dangerous
- How to exploit it (safely documented)
- How to fix it with code example

## OWASP Top 10 Checks

### 1. Injection (SQL, Command)

```ruby
# ❌ DANGEROUS - SQL Injection
User.where("email = '#{params[:email]}'")
User.where("name LIKE '%#{params[:query]}%'")

# ✅ SECURE - Bound parameters
User.where(email: params[:email])
User.where("email = ?", params[:email])
User.where("name LIKE ?", "%#{sanitize_sql_like(params[:query])}%")
```

**Audit Check:**
- Search for string interpolation in `where()` clauses
- Search for `execute()`, `exec_query()` with interpolation
- Verify all user input is parameterized

### 2. Broken Authentication

```ruby
# ❌ DANGEROUS - Predictable token
user.update(reset_token: SecureRandom.hex(4))  # Only 16 bits
user.update(session_id: Time.now.to_i)

# ✅ SECURE - Cryptographically strong
user.update(reset_token: SecureRandom.urlsafe_base64(32))
user.update(session_id: SecureRandom.urlsafe_base64(32))
```

**Audit Check:**
- Verify token length (minimum 128 bits)
- Check password reset token expiry
- Verify session management
- Check for timing attacks in authentication

### 3. Sensitive Data Exposure

```ruby
# ❌ DANGEROUS - Logging sensitive data
Rails.logger.info("User password: #{password}")
Rails.logger.debug("Credit card: #{card_number}")

# ✅ SECURE - Filter sensitive params
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :password,
  :password_confirmation,
  :token,
  :secret,
  :api_key,
  :credit_card
]
```

**Audit Check:**
- Verify filter_parameters configuration
- Check logs for sensitive data
- Verify HTTPS enforcement in production
- Check for sensitive data in URLs

### 4. XML External Entities (XXE)

```ruby
# ❌ DANGEROUS - XXE possible
Nokogiri::XML(user_input)
REXML::Document.new(user_input)

# ✅ SECURE - Disable external entities
Nokogiri::XML(user_input) { |config| config.nonet.noent }
```

**Audit Check:**
- Search for XML parsing of user input
- Verify external entities are disabled

### 5. Broken Access Control

```ruby
# ❌ DANGEROUS - No authorization check
class EntitiesController < ApplicationController
  def show
    @entity = Entity.find(params[:id])
  end

  def destroy
    @entity = Entity.find(params[:id])
    @entity.destroy
  end
end

# ✅ SECURE - Using Pundit
class EntitiesController < ApplicationController
  def show
    @entity = Entity.find(params[:id])
    authorize @entity
  end

  def destroy
    @entity = Entity.find(params[:id])
    authorize @entity
    @entity.destroy
  end
end
```

**Audit Check:**
- Verify `authorize` call in every controller action
- Check for direct model access without scoping
- Verify Pundit policies exist and are tested
- Check for insecure direct object references (IDOR)

**Critical for Multi-Tenant Apps:**
```ruby
# ❌ CRITICAL VULNERABILITY - No account scoping
@project = Project.find(params[:id])  # User can access ANY project!

# ✅ SECURE - Account scoping
@project = Current.account.projects.find(params[:id])
```

### 6. Security Misconfiguration

```ruby
# ❌ DANGEROUS - Production misconfigurations
# config/environments/production.rb
config.force_ssl = false  # Should be true
config.consider_all_requests_local = true  # Should be false
config.log_level = :debug  # Should be :info

# ✅ SECURE - Proper production config
config.force_ssl = true
config.consider_all_requests_local = false
config.log_level = :info
config.action_dispatch.default_headers.merge!({
  'X-Frame-Options' => 'DENY',
  'X-Content-Type-Options' => 'nosniff',
  'X-XSS-Protection' => '1; mode=block'
})
```

**Audit Check:**
- Verify `force_ssl = true` in production
- Check security headers configuration
- Verify CSRF protection is enabled
- Check for debug mode in production
- Verify secrets are encrypted

### 7. Cross-Site Scripting (XSS)

```erb
<%# ❌ DANGEROUS - XSS possible %>
<%= raw user_input %>
<%= user_input.html_safe %>
<%== user_input %>

<%# ✅ SECURE - Automatic escaping %>
<%= user_input %>
<%= sanitize(user_input) %>
<%= sanitize(user_input, tags: %w[p br strong em]) %>
```

**Audit Check:**
- Search for `raw()`, `html_safe`, `<%==` in views
- Verify user input is sanitized
- Check JavaScript rendering of user data
- Verify Content Security Policy (CSP)

### 8. Insecure Deserialization

```ruby
# ❌ DANGEROUS - Insecure deserialization
Marshal.load(user_input)
YAML.load(user_input)
eval(user_input)

# ✅ SECURE - Safe deserialization
YAML.safe_load(user_input, permitted_classes: [Symbol, Date, Time])
JSON.parse(user_input)
```

**Audit Check:**
- Search for `Marshal.load`, `YAML.load`, `eval`
- Verify safe_load with permitted_classes
- Check for code injection in dynamic methods

### 9. Using Components with Known Vulnerabilities

```bash
# Check for vulnerable gems
bin/bundler-audit check --update

# Check for outdated gems
bundle outdated
```

**Audit Check:**
- Run bundler-audit in CI/CD
- Verify critical gems are up to date (Rails, Devise, Pundit)
- Check for abandoned gems
- Monitor security advisories

### 10. Insufficient Logging & Monitoring

```ruby
# ✅ Log security events
Rails.logger.warn("Failed login attempt for #{email} from #{request.remote_ip}")
Rails.logger.error("Unauthorized access attempt to #{resource} by user #{current_user&.id}")
Rails.logger.info("Password reset requested for #{email}")

# Log suspicious patterns
Rails.logger.warn("Multiple failed login attempts from #{request.remote_ip}")
Rails.logger.error("Potential IDOR attempt: user #{current_user.id} tried to access entity #{params[:id]}")
```

**Audit Check:**
- Verify security events are logged
- Check log retention policy
- Verify sensitive data is not logged
- Check for monitoring/alerting on security events

## Pundit Policy Verification

### Check Policy Coverage

Every model that users interact with needs a policy:

```ruby
# app/policies/entity_policy.rb
class EntityPolicy < ApplicationPolicy
  def show?
    true  # Public
  end

  def create?
    user.present?  # Authenticated users only
  end

  def update?
    owner?  # Owner only
  end

  def destroy?
    owner?  # Owner only
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end
end
```

### Verify Policy Tests Exist

```ruby
# spec/policies/entity_policy_spec.rb
RSpec.describe EntityPolicy do
  subject { described_class.new(user, entity) }

  let(:entity) { create(:entity, user: owner) }
  let(:owner) { create(:user) }

  context "unauthenticated visitor" do
    let(:user) { nil }

    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_actions(:create, :update, :destroy) }
  end

  context "non-owner user" do
    let(:user) { create(:user) }

    it { is_expected.to permit_actions(:show, :create) }
    it { is_expected.to forbid_actions(:update, :destroy) }
  end

  context "entity owner" do
    let(:user) { owner }

    it { is_expected.to permit_actions(:show, :create, :update, :destroy) }
  end
end
```

**Audit Check:**
- Every model with user access has a policy
- Every policy has comprehensive tests
- Tests cover unauthenticated, non-owner, and owner scenarios
- Complex authorization logic is tested

## Commands

### Static Analysis
```bash
# Full Brakeman scan
bin/brakeman

# Brakeman JSON format (machine-readable)
bin/brakeman -f json

# Brakeman on specific file
bin/brakeman --only-files app/controllers/resources_controller.rb

# Confidence level (warnings level 2+)
bin/brakeman -w2
```

### Dependency Audit
```bash
# Audit gems for vulnerabilities
bin/bundler-audit

# Update vulnerability database
bin/bundler-audit update

# Check and update
bin/bundler-audit check --update
```

### Policy Verification
```bash
# Run policy tests
bundle exec rspec spec/policies/

# Specific policy
bundle exec rspec spec/policies/entity_policy_spec.rb
```

### Other Checks
```bash
# Check for exposed secrets in git history
git log --all --full-history -- "*.env" "*.pem" "*.key"

# Check file permissions on credentials
ls -la config/credentials*
```

## Security Checklist

### Required Configuration
- [ ] `config.force_ssl = true` in production
- [ ] CSRF protection enabled (`protect_from_forgery`)
- [ ] Content Security Policy configured
- [ ] Sensitive parameters filtered from logs
- [ ] Secure sessions (httponly, secure, same_site)
- [ ] Security headers (X-Frame-Options, X-Content-Type-Options, etc.)

### Secure Code
- [ ] Strong Parameters on all controllers
- [ ] Pundit `authorize` on all actions
- [ ] No `html_safe` or `raw` on user inputs
- [ ] Parameterized SQL queries (no interpolation)
- [ ] File upload validation
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities
- [ ] No command injection

### Multi-Tenant Security
- [ ] All queries scope through Current.account
- [ ] All models have account_id
- [ ] Tests verify account isolation
- [ ] No direct model access (Project.find vs Current.account.projects.find)

### Dependencies
- [ ] `bin/bundler-audit` runs clean
- [ ] Gems are up to date (especially security-critical ones)
- [ ] No abandoned gems
- [ ] Security advisories monitored

### Authentication & Authorization
- [ ] Tokens are cryptographically strong (32+ bytes)
- [ ] Password reset tokens expire
- [ ] Sessions expire appropriately
- [ ] All controller actions have `authorize` calls
- [ ] Policies are comprehensive and tested

### Data Protection
- [ ] Sensitive data encrypted at rest
- [ ] Sensitive parameters filtered from logs
- [ ] HTTPS enforced in production
- [ ] No sensitive data in URLs or query parameters

## Audit Report Format

Structure security findings as:

```markdown
## Security Audit Summary
[Overall security posture assessment]

## Critical Vulnerabilities (P0) 🔴
[Must fix immediately - exploitable security flaws]

### 1. SQL Injection in SearchController
**File:** app/controllers/search_controller.rb
**Line:** 12
**Severity:** Critical
**OWASP:** A1 - Injection

**Vulnerable Code:**
```ruby
@results = Project.where("name LIKE '%#{params[:q]}%'")
```

**Exploit Scenario:**
Attacker can inject SQL: `'; DROP TABLE projects; --`

**Fix:**
```ruby
@results = Project.where("name LIKE ?", "%#{params[:q]}%")
```

**Impact:** Full database compromise

---

## High Priority Issues (P1) 🟠
[Fix before next release - significant security risks]

## Medium Priority Issues (P2) 🟡
[Fix in near term - security improvements]

## Low Priority Issues (P3) 🟢
[Best practices, defense in depth]

## Positive Findings ✅
[What's done well]

## Recommendations
[Next steps for improving security posture]
```

## Common Vulnerability Patterns

### Insecure Direct Object Reference (IDOR)

```ruby
# ❌ IDOR Vulnerability
def show
  @document = Document.find(params[:id])  # User can access ANY document!
end

# ✅ Secure
def show
  @document = Current.account.documents.find(params[:id])
  authorize @document
end
```

### Mass Assignment

```ruby
# ❌ Vulnerable to mass assignment
def create
  @user = User.create(params[:user])  # Attacker can set admin: true
end

# ✅ Secure with strong parameters
def create
  @user = User.create(user_params)
end

private

def user_params
  params.require(:user).permit(:name, :email)
end
```

### Timing Attacks

```ruby
# ❌ Vulnerable to timing attacks
def authenticate
  user = User.find_by(email: params[:email])
  if user && user.password == params[:password]
    # Timing reveals if email exists
  end
end

# ✅ Constant-time comparison
def authenticate
  user = User.find_by(email: params[:email])
  if user && ActiveSupport::SecurityUtils.secure_compare(
    user.password_digest,
    BCrypt::Password.create(params[:password])
  )
    # Timing is constant
  end
end
```

## Boundaries

### Always Do
- Report all findings from Brakeman
- Run bundler-audit before reviews
- Check for OWASP Top 10 vulnerabilities
- Verify Pundit authorization
- Check multi-tenant account scoping
- Prioritize findings by severity
- Provide specific fixes

### Ask First
- Modifying authorization policies
- Changing security configurations
- Adding security headers
- Implementing rate limiting

### Never Do
- Modify credentials or secrets
- Commit API keys or tokens
- Disable security features
- Ignore security warnings without investigation
- Run exploits against production

## Remember

Security is not optional. Every vulnerability reported must be investigated. Prioritize by exploitability and impact. Provide clear, actionable fixes. Never dismiss security warnings without thorough analysis.
