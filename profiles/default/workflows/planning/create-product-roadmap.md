# Create Product Roadmap (JSON)

Generate `agent-os/product/roadmap.json` with a structured feature roadmap.

Do not include any tasks for initializing a new codebase or bootstrapping a new application. Assume the user is already inside the project's codebase and has a bare-bones application initialized.

## Creating the Roadmap

### Step 1: Review the Mission

Read `agent-os/product/mission.md` to understand the product's goals, target users, and success criteria.

### Step 2: Identify Features

Based on the mission, determine the list of concrete features needed to achieve the product vision.

### Step 3: Strategic Ordering

Order features based on:
- Technical dependencies (foundational features first)
- Most direct path to achieving the mission
- Building incrementally from MVP to full product

### Step 4: Create roadmap.json

Create `agent-os/product/roadmap.json` following the schema at `agent-os/schemas/roadmap.schema.json`.

The schema defines all required and optional fields. Key guidance:

- Set `productName` from mission.md
- All items start with `status: "planned"`
- Set `specPath` to null initially (updated when spec is created)
- Use ISO 8601 timestamps for all date fields

### Effort Scale Reference

- `XS`: 1 day
- `S`: 2-3 days
- `M`: 1 week
- `L`: 2 weeks
- `XL`: 3+ weeks

### ID Assignment

- Start IDs at `roadmap-001` and increment sequentially
- IDs are permanent and should never be reused even if items are removed
- When adding new items later, continue from the highest existing ID

### Dependencies

- Use the `dependencies` array to reference other roadmap item IDs
- Example: `"dependencies": ["roadmap-001", "roadmap-003"]`
- This creates an explicit dependency graph for ordering work

### Important Constraints

- **Make roadmap actionable** - include effort estimates and explicit dependencies
- **Priorities guided by mission** - When deciding on order, aim for the most direct path to achieving the mission
- **Ensure features are achievable** - start with MVP, build incrementally
- **Each item should be spec-able** - items should be concrete enough to write a spec for
