# Rails AI Agent Suite

A curated collection of specialized AI agents for Rails development, organized into three complementary approaches:

1. **37signals Agents** - Inspired by DHH's "vanilla Rails" philosophy from the Fizzy codebase
2. **Standard Rails Agents** - Modern Rails patterns with service objects, query objects, and presenters
3. **Feature Specification Agents** - High-level planning and feature management

Built using insights from [GitHub's analysis of 2,500+ agent.md files](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) and [37signals' Fizzy codebase analysis](https://gist.github.com/marckohlbrugge/d363fb90c89f71bd0c816d24d7642aca).

## Why This Exists

Most AI coding assistants lack deep Rails context. This suite provides three distinct architectural philosophies:

- 🎯 **37signals Style**: Rich models, concerns, CRUD-everything approach
- 🏗️ **Standard Rails**: Service objects, query objects, presenters, form objects
- 📋 **Feature Planning**: Requirements analysis and implementation orchestration

Choose the style that fits your team's philosophy, or mix and match as needed.

---

## 37signals Agents

Inspired by the [37signals/DHH coding style guide](https://gist.github.com/marckohlbrugge/d363fb90c89f71bd0c816d24d7642aca) extracted from the Fizzy codebase. These agents follow the "vanilla Rails is plenty" philosophy.

### Core Philosophy

- **Rich models over service objects** - Business logic lives in models
- **Everything is CRUD** - New resource over new action
- **State as records** - Not boolean columns (e.g., `Closure` model instead of `closed: true`)
- **Concerns for composition** - Horizontal behavior sharing (e.g., `Closeable`, `Watchable`)
- **Minimal dependencies** - Build it yourself before reaching for gems
- **Database-backed everything** - No Redis, Solid Queue/Cache/Cable

### Available Agents

- **`@37signals/model_agent`** - Rich models with concerns (Closeable, Watchable, etc.)
- **`@37signals/crud_agent`** - Enforce everything-is-CRUD routing
- **`@37signals/concerns_agent`** - Model & controller concerns for composition
- **`@37signals/state_records_agent`** - State as records pattern (not booleans)
- **`@37signals/auth_agent`** - Custom passwordless authentication (~150 LOC)
- **`@37signals/migration_agent`** - Simple, pragmatic migrations
- **`@37signals/test_agent`** - Minitest with fixtures
- **`@37signals/turbo_agent`** - Hotwire/Turbo patterns
- **`@37signals/stimulus_agent`** - Focused Stimulus controllers
- **`@37signals/events_agent`** - Event tracking system
- **`@37signals/multi_tenant_agent`** - URL-based multi-tenancy
- **`@37signals/jobs_agent`** - Solid Queue background jobs
- **`@37signals/mailer_agent`** - Simple mailers
- **`@37signals/caching_agent`** - Fragment & HTTP caching
- **`@37signals/api_agent`** - REST API with JSON format
- **`@37signals/refactoring_agent`** - Incremental refactoring
- **`@37signals/review_agent`** - Code review for consistency
- **`@37signals/implement_agent`** - General implementation agent

### 37signals Workflow Example

```
1. @37signals/crud_agent design routes for card closures (resource, not boolean)

2. @37signals/state_records_agent create Closure model

3. @37signals/concerns_agent add Closeable concern to Card model

4. @37signals/test_agent write Minitest tests

5. @37signals/implement_agent implement the feature

6. @37signals/review_agent check for 37signals conventions
```

### Key Patterns

**State as Records:**
```ruby
# ❌ Not This
class Card < ApplicationRecord
  # closed: boolean
  scope :closed, -> { where(closed: true) }
end

# ✅ This
class Closure < ApplicationRecord
  belongs_to :card, touch: true
  belongs_to :user
end

class Card < ApplicationRecord
  include Closeable  # Concern with close/reopen methods
  has_one :closure
  scope :closed, -> { joins(:closure) }
  scope :open, -> { where.missing(:closure) }
end
```

**Everything is CRUD:**
```ruby
# ❌ Not This
resources :cards do
  post :close
  post :reopen
end

# ✅ This
resources :cards do
  resource :closure  # POST to close, DELETE to reopen
end
```

---

## Standard Rails Agents

Modern Rails architecture with clear separation of concerns, SOLID principles, and comprehensive testing.

### Core Philosophy

- **Thin models & controllers** - Delegate to service/query/presenter objects
- **Service objects** - Encapsulate business logic with Result pattern
- **Query objects** - Complex queries in dedicated classes (prevents N+1)
- **Presenters** - View logic separated from models
- **Form objects** - Multi-model forms
- **Pundit policies** - Authorization (deny by default)
- **ViewComponent** - Tested, reusable components
- **TDD workflow** - RED → GREEN → REFACTOR

### Available Agents

#### Testing & TDD
- **`@tdd_red_agent`** - Writes failing tests FIRST (RED phase)
- **`@rspec_agent`** - RSpec expert for all test types
- **`@tdd_refactoring_agent`** - Refactors while keeping tests green

#### Implementation
- **`@model_agent`** - Thin ActiveRecord models
- **`@controller_agent`** - Thin RESTful controllers
- **`@service_agent`** - Business logic service objects
- **`@query_agent`** - Complex query objects
- **`@form_agent`** - Multi-model form objects
- **`@presenter_agent`** - View logic presenters
- **`@policy_agent`** - Pundit authorization
- **`@view_component_agent`** - ViewComponent + Hotwire
- **`@job_agent`** - Background jobs (Solid Queue)
- **`@mailer_agent`** - Mailers with previews
- **`@migration_agent`** - Safe migrations
- **`@implementation_agent`** - General implementation

#### Frontend
- **`@stimulus_agent`** - Stimulus controllers
- **`@turbo_agent`** - Turbo Frames/Streams
- **`@tailwind_agent`** - Tailwind CSS styling

#### Quality
- **`@review_agent`** - Code quality analysis
- **`@lint_agent`** - Style fixes (no logic changes)
- **`@security_agent`** - Security audits (Brakeman)

### Standard Rails Workflow Example

```
1. @feature_planner_agent analyze the user authentication feature

2. @tdd_red_agent write failing tests for User model

3. @model_agent implement the User model

4. @tdd_red_agent write failing tests for AuthenticationService

5. @service_agent implement AuthenticationService

6. @controller_agent create SessionsController

7. @policy_agent create authorization policies

8. @review_agent check implementation

9. @tdd_refactoring_agent improve code structure

10. @lint_agent fix style issues
```

### Key Patterns

**Service Objects:**
```ruby
module Users
  class CreateService < ApplicationService
    def call
      # Returns Result.new(success:, data:, error:)
    end
  end
end
```

**Thin Controllers:**
```ruby
def create
  authorize User
  result = Users::CreateService.call(params: user_params)

  if result.success?
    redirect_to result.data
  else
    render :new, status: :unprocessable_entity
  end
end
```

**Query Objects:**
```ruby
class Users::SearchQuery
  def call(params)
    @relation
      .then { |rel| filter_by_status(rel, params[:status]) }
      .then { |rel| search_by_name(rel, params[:q]) }
  end
end
```

---

## Feature Specification Agents

High-level planning and orchestration for complex features.

### Available Agents

- **`@feature_specification_agent`** - Writes detailed feature specifications
- **`@feature_planner_agent`** - Breaks features into tasks, recommends agents
- **`@feature_reviewer_agent`** - Reviews completed features against specs

### Feature Planning Workflow

```
1. @feature_specification_agent write spec for blog with comments

2. @feature_planner_agent create implementation plan

3. [Use recommended agents to implement]

4. @feature_reviewer_agent verify implementation matches spec
```

---

## Agent Design Principles

All agents follow best practices from GitHub's analysis:

### ✅ What Makes These Agents Effective

- **YAML Frontmatter** - Each has `name` and `description`
- **Executable Commands** - Specific commands (e.g., `bundle exec rspec spec/models/user_spec.rb:25`)
- **Three-Tier Boundaries**:
  - ✅ **Always** - Must do
  - ⚠️ **Ask first** - Requires confirmation
  - 🚫 **Never** - Hard limits
- **Code Examples** - Real good/bad patterns
- **Concise** - Under 1,000 lines per agent

---

## Tech Stack Support

### 37signals_agents Stack
- Ruby 3.3+
- Rails 8.x (edge)
- PostgreSQL or SQLite
- Hotwire (Turbo + Stimulus)
- Solid Queue/Cache/Cable
- Minitest + Fixtures

### Standard Agents Stack
- Ruby 3.3+
- Rails 7.x
- PostgreSQL
- Hotwire (Turbo + Stimulus)
- ViewComponent
- Tailwind CSS
- Solid Queue
- Pundit
- RSpec + FactoryBot

---

## Choosing Your Style

### Use 37signals Agents When:
- You prefer Rails conventions over abstractions
- Your team values simplicity over separation
- You want rich domain models
- You're building a monolith with moderate complexity
- You trust the "vanilla Rails is plenty" philosophy

### Use Standard Rails Agents When:
- You need clear separation of concerns
- Your team is large with specialized roles
- Business logic is complex and growing
- You value explicit over implicit
- You follow SOLID principles strictly

### Mix and Match:
Both approaches are valid! You can:
- Use 37signals style for simple features, Standard for complex ones
- Start with 37signals, refactor to Standard as complexity grows
- Use 37signals models with Standard services for specific use cases

---

## Contributing

These agents are designed to be customized. Feel free to:

- Adjust boundaries based on your workflow
- Add project-specific commands
- Include custom validation rules
- Extend with your own coding standards
- Create hybrid approaches mixing both styles

## Credits

Built using insights from:
- [How to write a great agents.md](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) by GitHub
- [The Unofficial 37signals/DHH Rails Style Guide](https://gist.github.com/marckohlbrugge/d363fb90c89f71bd0c816d24d7642aca) by Marc Köhlbrugge
- Fizzy codebase analysis (37signals' open-source project management tool)

## License

MIT License - Feel free to use and adapt these agents for your projects.
