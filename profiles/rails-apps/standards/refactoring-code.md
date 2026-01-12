---
name: refactoring-code
description: Orchestrates incremental refactoring of Rails codebases toward modern patterns by analyzing anti-patterns and coordinating specialized transformations
---

# Code Refactoring Skill

Orchestrates incremental refactoring of Rails codebases toward modern patterns. Analyzes legacy code, identifies anti-patterns, plans safe refactorings, and transforms code while maintaining functionality.

## Quick Start

Run a refactoring:
1. Analyze current code for anti-patterns
2. Plan incremental refactoring steps
3. Add tests for existing behavior
4. Make small, safe changes
5. Run tests after each change
6. Deploy incrementally

## Core Principles

### 1. Incremental, Not Big Rewrites

```ruby
# ❌ BAD: Big rewrite all at once
def refactor_codebase
  # Delete everything
  # Rebuild from scratch
  # Break production
end

# ✅ GOOD: Incremental refactoring
def refactor_codebase
  # 1. Add tests for existing behavior
  # 2. Make small, safe changes
  # 3. Run tests after each change
  # 4. Deploy incrementally
  # 5. Keep both old and new code during transition
end
```

### 2. Test First, Always

Before any refactoring:
1. Add tests for existing behavior
2. Ensure 100% test coverage for code being refactored
3. Tests should pass before refactoring starts
4. Tests should pass after each refactoring step

### 3. Feature Flags for Risky Changes

For major refactorings:
1. Implement new code alongside old code
2. Add feature flag to switch between implementations
3. Test in production with flag
4. Gradually roll out
5. Remove old code after successful migration

### 4. Backward Compatibility

During transitions:
1. Support both old and new interfaces
2. Deprecate old interface with warnings
3. Provide migration guide
4. Remove old interface after grace period

## Common Refactoring Patterns

### Pattern 1: Service Object to Model Method

**Scenario:** Service object doing simple work that belongs in model.

**Before:**
```ruby
class ProjectCreationService
  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    project = Project.new(@params)
    project.creator = @user
    project.save!
    NotificationMailer.project_created(project).deliver_later
    project
  end
end

# Usage
ProjectCreationService.new(current_user, params).call
```

**After:**
```ruby
class Project < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  after_create_commit :notify_team

  private

  def notify_team
    NotificationMailer.project_created(self).deliver_later
  end
end

# Usage
Project.create!(params)
```

**Refactoring Steps:**
1. Add tests for existing service object behavior
2. Move business logic to model methods
3. Add callbacks for side effects
4. Update tests to call model methods
5. Update controllers to use model methods
6. Delete service object files
7. Run full test suite

### Pattern 2: Boolean to State Record

**Scenario:** Boolean flags that should be state records.

**Before:**
```ruby
class Project < ApplicationRecord
  # closed: boolean
  # closed_at: datetime
  # closed_by_id: integer

  scope :open, -> { where(closed: false) }
  scope :closed, -> { where(closed: true) }

  def close!(user)
    update!(closed: true, closed_at: Time.current, closed_by_id: user.id)
  end
end
```

**After:**
```ruby
class Project < ApplicationRecord
  has_one :closure, dependent: :destroy

  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }

  def close!(user)
    create_closure!(user: user)
  end

  def closed?
    closure.present?
  end
end

class Closure < ApplicationRecord
  belongs_to :project, touch: true
  belongs_to :user
  belongs_to :account, default: -> { project.account }
end
```

**Refactoring Steps:**
1. Create migration for closures table
2. Create Closure model
3. Backfill closure records from boolean column
4. Update Project model associations
5. Update scopes to use state records
6. Update tests to use state records
7. Remove boolean columns (separate migration)

### Pattern 3: Custom Actions to CRUD Resources

**Scenario:** Controller with custom actions that should be resources.

**Before:**
```ruby
class ProjectsController < ApplicationController
  def archive
    @project.update(archived: true)
    redirect_to @project
  end

  def unarchive
    @project.update(archived: false)
    redirect_to @project
  end

  def approve
    @project.update(approved: true)
    redirect_to @project
  end
end

# routes.rb
resources :projects do
  member do
    post :archive
    post :unarchive
    post :approve
  end
end
```

**After:**
```ruby
class ArchivalsController < ApplicationController
  def create
    @project.create_archival!
    redirect_to @project
  end

  def destroy
    @project.archival.destroy!
    redirect_to @project
  end
end

class ApprovalsController < ApplicationController
  def create
    @project.create_approval!(approver: Current.user)
    redirect_to @project
  end
end

# routes.rb
resources :projects do
  resource :archival, only: [:create, :destroy]
  resource :approval, only: [:create]
end
```

**Refactoring Steps:**
1. Create Archival and Approval state record models
2. Create ArchivalsController and ApprovalsController
3. Update routes to use resources
4. Update views to use new routes
5. Add tests for new controllers
6. Remove old custom actions
7. Run full test suite

### Pattern 4: Fat Controller to Thin Controller

**Scenario:** Controller with business logic that should be in model.

**Before:**
```ruby
class CommentsController < ApplicationController
  def create
    @comment = @card.comments.build(comment_params)
    @comment.creator = Current.user
    @comment.account = Current.account

    if @comment.body.match?(/@\w+/)
      mentions = @comment.body.scan(/@(\w+)/).flatten
      users = User.where(username: mentions)
      users.each do |user|
        NotificationMailer.mentioned(user, @comment).deliver_later
      end
    end

    @comment.save!
    redirect_to @card
  end
end
```

**After:**
```ruby
class CommentsController < ApplicationController
  def create
    @comment = @card.comments.create!(comment_params)
    redirect_to @card
  end
end

class Comment < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { card.account }
  after_create_commit :notify_mentions

  def mentioned_users
    usernames = body.scan(/@(\w+)/).flatten
    account.users.where(username: usernames)
  end

  private

  def notify_mentions
    mentioned_users.each do |user|
      NotificationMailer.mentioned(user, self).deliver_later
    end
  end
end
```

**Refactoring Steps:**
1. Add tests for existing controller behavior
2. Move mention parsing to Comment#mentioned_users
3. Move notification logic to after_create_commit callback
4. Add default values with lambdas
5. Simplify controller to just create and redirect
6. Update tests to verify model behavior
7. Run full test suite

### Pattern 5: Duplicate Code to Concern

**Scenario:** Multiple models with duplicate closeable behavior.

**Before:**
```ruby
class Card < ApplicationRecord
  has_one :closure
  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }
  def close!; create_closure!; end
  def closed?; closure.present?; end
end

class Project < ApplicationRecord
  # Same closeable behavior duplicated
  has_one :closure
  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }
  def close!; create_closure!; end
  def closed?; closure.present?; end
end
```

**After:**
```ruby
# app/models/concerns/closeable.rb
module Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, as: :closeable, dependent: :destroy
    scope :open, -> { where.missing(:closure) }
    scope :closed, -> { joins(:closure) }
  end

  def close!(user = nil)
    create_closure!(user: user)
  end

  def closed?
    closure.present?
  end
end

class Card < ApplicationRecord
  include Closeable
end

class Project < ApplicationRecord
  include Closeable
end

class Closure < ApplicationRecord
  belongs_to :closeable, polymorphic: true, touch: true
  belongs_to :user
end
```

**Refactoring Steps:**
1. Identify duplicate patterns across models
2. Create concern with shared behavior
3. Make Closure polymorphic
4. Add tests for concern in isolation
5. Include concern in models
6. Remove duplicate code from models
7. Verify existing tests still pass

### Pattern 6: AJAX to Turbo Streams

**Scenario:** jQuery AJAX that should be Turbo Streams.

**Before:**
```javascript
// app/assets/javascripts/comments.js
$(document).on('click', '.comment-form button', function(e) {
  e.preventDefault();

  $.ajax({
    url: '/comments',
    method: 'POST',
    data: $(this).closest('form').serialize(),
    success: function(data) {
      $('.comments').append(data.html);
      $('form')[0].reset();
    }
  });
});
```

**After:**
```erb
<%# app/views/comments/create.turbo_stream.erb %>
<%= turbo_stream.append "comments", @comment %>
<%= turbo_stream.replace "comment_form", partial: "comments/form" %>

<%# Form with Turbo %>
<%= form_with model: [@card, Comment.new], id: "comment_form" do |f| %>
  <%= f.text_area :body %>
  <%= f.submit %>
<% end %>
```

**Refactoring Steps:**
1. Remove jQuery dependency
2. Update form to use form_with (Turbo-enabled)
3. Create Turbo Stream response template
4. Remove JavaScript AJAX handlers
5. Add system test for Turbo behavior
6. Verify real-time updates work

## Refactoring Workflow

### Phase 1: Analysis

1. **Identify anti-patterns**
   - Service objects that should be model methods
   - Boolean flags that should be state records
   - Fat controllers with business logic
   - Duplicate code across models
   - Custom controller actions

2. **Assess scope**
   - How many files affected?
   - Test coverage percentage?
   - Dependencies between changes?
   - Risk level?

3. **Plan refactoring steps**
   - Break into smallest possible changes
   - Order by dependencies
   - Identify feature flag needs
   - Estimate timeline

### Phase 2: Preparation

1. **Add tests for existing behavior**
   - Ensure 90%+ coverage
   - Test edge cases
   - Test integration points
   - Verify all tests pass

2. **Create feature flags (if needed)**
   - For risky changes
   - For gradual rollout
   - For A/B testing

3. **Plan data migrations**
   - Backfill strategies
   - Zero-downtime approach
   - Rollback plan

### Phase 3: Execution

1. **Make smallest change**
   - One refactoring at a time
   - Keep changes focused
   - Maintain backward compatibility

2. **Run tests**
   - After each change
   - Full suite
   - Fix any failures immediately

3. **Commit**
   - Clear commit messages
   - Reference issue/ticket
   - Document decision

4. **Repeat**
   - Continue incremental changes
   - Deploy frequently
   - Monitor for issues

### Phase 4: Cleanup

1. **Remove old code**
   - After new code is proven
   - After feature flag rollout complete
   - After grace period

2. **Update documentation**
   - Code comments
   - README changes
   - Migration guides

3. **Remove feature flags**
   - Clean up conditional code
   - Simplify logic

## Decision Matrix

### When to Refactor

**Refactor incrementally when:**
- App is in production with users
- Core functionality works
- Team needs to maintain velocity
- Can deploy changes gradually
- Tests exist or can be added

**Consider rewrite when:**
- App is a prototype/MVP
- Tech debt is overwhelming
- No tests exist and adding them is prohibitive
- Architecture is fundamentally wrong
- Faster to rebuild than refactor

### What to Refactor First

**High Priority:**
1. Security issues (SQL injection, authorization bypass)
2. Performance bottlenecks (N+1 queries, missing indexes)
3. Code causing most bugs
4. Remove external dependencies (Redis, complex gems)

**Medium Priority:**
1. Service objects to model methods
2. Booleans to state records
3. Fat controllers to thin controllers
4. Complex JavaScript to Turbo/Stimulus

**Low Priority:**
1. Naming conventions
2. File organization
3. Comment improvements
4. Cosmetic changes

## Common Anti-Patterns

### God Controller
```ruby
# ❌ Too many responsibilities
class ProjectsController < ApplicationController
  def index; end
  def show; end
  def create; end
  def update; end
  def destroy; end
  def archive; end      # Should be ArchivalsController
  def publish; end      # Should be PublicationsController
  def approve; end      # Should be ApprovalsController
end

# ✅ Focused resources
class ProjectsController < ApplicationController
  # Just CRUD
end

class ArchivalsController < ApplicationController
  def create; end
  def destroy; end
end
```

### Service Object Overuse
```ruby
# ❌ Service object for simple logic
class ProjectDuplicationService
  def initialize(project, user)
    @project = project
    @user = user
  end

  def call
    new_project = @project.dup
    new_project.creator = @user
    new_project.save!
    new_project
  end
end

# ✅ Model method
class Project < ApplicationRecord
  def duplicate_for(user)
    transaction do
      new_project = dup
      new_project.creator = user
      new_project.save!
      new_project
    end
  end
end
```

### Boolean Instead of State
```ruby
# ❌ Boolean with metadata
class Project < ApplicationRecord
  # approved: boolean
  # approved_at: timestamp
  # approved_by_id: integer
end

# ✅ State record
class Project < ApplicationRecord
  has_one :approval
end

class Approval < ApplicationRecord
  belongs_to :project
  belongs_to :approver, class_name: "User"
end
```

## Example Refactoring Plan

**User Request:** "Our app has 50+ service objects that should be model methods."

**Response:**

```
I'll help you refactor service objects to model methods incrementally. Here's my analysis and plan:

## Current State Analysis

Identified issues:
- 50+ service objects (unnecessary abstraction)
- Business logic outside models (violates Rails conventions)
- Complex test setup with factories (should use fixtures)
- Fat controllers depending on services (should be thin)

## Refactoring Plan (Incremental)

### Phase 1: Audit (Week 1)
1. List all service objects and usage
2. Audit test coverage (ensure 90%+)
3. Identify highest-impact services to refactor first
4. Prioritize by: frequency of use, complexity, bugs

### Phase 2: Refactor Core Services (Weeks 2-4)
One service per day approach:

For each service:
1. Add comprehensive tests if missing
2. Move logic to model method
3. Add callbacks for side effects
4. Update controller to call model method
5. Update tests
6. Delete service file
7. Run full test suite
8. Deploy

Start with:
- ProjectCreationService → Project.create_with_defaults
- CardDuplicationService → Card#duplicate_for
- UserInvitationService → User#invite

### Phase 3: Remaining Services (Weeks 5-6)
Continue refactoring remaining services at sustainable pace.

### Phase 4: Cleanup (Week 7)
1. Remove app/services directory
2. Update documentation
3. Create guidelines to prevent service object proliferation

## Risk Mitigation

- All changes behind feature flags for critical paths
- Maintain test coverage at 90%+
- Deploy daily with small changes
- Monitor error rates
- Rollback plan for each change

## Success Metrics

- Remove ~3,000 lines of service object code
- Reduce test suite complexity
- Improve code discoverability
- Zero production incidents

Proceed with Phase 1 audit?
```

## Boundaries

### Always Do
- Test existing behavior before refactoring
- Make incremental changes
- Run tests after each change
- Maintain backward compatibility during transitions
- Use feature flags for risky changes
- Deploy refactorings gradually
- Document refactoring decisions

### Ask First
- Timeline and pace for refactoring
- Risk tolerance for changes
- Whether feature flags are available
- Test coverage requirements
- Data migration strategies
- Support period for old code

### Never Do
- Rewrite everything at once
- Refactor without tests
- Make changes that break production
- Remove old code before new code is proven
- Skip the analysis phase
- Ignore backward compatibility
- Deploy all changes at once
- Remove safety nets prematurely

## Remember

Refactoring is about improving code structure without changing behavior. Test first, change incrementally, verify constantly. Keep production stable. Small steps lead to big improvements. When in doubt, make the change smaller.
