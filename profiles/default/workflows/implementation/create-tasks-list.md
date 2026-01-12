# Task List Creation (JSON)

## Core Responsibilities

1. **Analyze spec and requirements**: Read and analyze the spec.md and/or requirements.md to inform the tasks list
2. **Plan task execution order**: Break the requirements into tasks with explicit dependencies
3. **Group tasks by specialization**: Group tasks that require the same skill or stack specialization
4. **Create tasks.json**: Create the structured tasks file with full metadata
5. **Update spec-meta.json**: Mark the spec as tasked and update timestamps

## Workflow

### Step 1: Analyze Spec & Requirements

Read each of these files (whichever are available) and analyze them:
- `agent-os/specs/[this-spec]/spec.md`
- `agent-os/specs/[this-spec]/planning/requirements.md`
- `agent-os/specs/[this-spec]/spec-meta.json` (to get roadmapItemId)

Use your learnings to inform the tasks list and groupings.

### Step 1.5: Verify Spec Completeness (for refactoring tasks)

**CRITICAL:** Before creating tasks, verify the spec has identified ALL affected code. This prevents missing critical updates that could break the application.

**When to perform verification:**
- The spec involves modifying shared constants, types, or patterns
- The spec involves renaming or changing values used across files
- The spec mentions any kind of refactoring

**How to verify:**

1. **Identify key constants/types from the spec:**
   Extract the main constants, types, or patterns being modified from the spec.

2. **Run independent impact verification:**
   ```bash
   # For each constant/type being modified, search entire codebase
   grep -r "CONSTANT_NAME" . | wc -l

   # List unique directories with matches
   grep -r "CONSTANT_NAME" . | cut -d':' -f1 | xargs -I{} dirname {} | sort -u
   ```

3. **Compare against spec:**
   - Count files/packages mentioned in spec
   - Compare with grep results
   - If grep finds MORE files/packages than spec mentions, the spec may be INCOMPLETE

4. **Check for duplicate definitions:**
   ```bash
   # Detect if same constant is defined in multiple places
   grep -rn "CONSTANT_NAME" . | grep -E "(export|define|const|var|let|=)"
   ```
   If duplicates exist but aren't mentioned in spec, flag this.

5. **If gaps found:**
   - Document the missing files/packages discovered
   - Create additional task groups to address them
   - Add a note about gaps in the task group descriptions

### Step 2: Create tasks.json

Generate `agent-os/specs/[this-spec]/tasks.json` following the schema at `agent-os/schemas/tasks.schema.json`.

The schema defines all required and optional fields. Key guidance:

- Set `specId` to the spec folder name (e.g., `2025-01-10-user-auth`)
- Set `roadmapItemId` from spec-meta.json (or null if not linked)
- All new items start with `status: "pending"`
- Use ISO 8601 timestamps for all date fields

### Step 3: Populate Task Groups

For each logical grouping of work, create a task group following the `taskGroup` definition in the schema.

Key guidance for task groups:
- Use descriptive names like "Database Layer" or "User Authentication API"
- Set the appropriate `layer` value (see Layer Types below)
- Include 3-5 `acceptanceCriteria` that define completion
- Leave `assignedAgent` as null (used during orchestration)

### Step 4: Populate Tasks and Subtasks

For each task within a group, follow the `task` and `subtask` definitions in the schema.

Key guidance for tasks:
- Make titles action-oriented: "Create User model with validations"
- Use `details` array in subtasks for specific implementation points
- Leave `notes` as null initially (populated during implementation)

### Step 5: Update Summary Statistics

After populating all task groups, calculate the `summary` object:
- `totalTaskGroups`: Count of all task groups
- `completedTaskGroups`: 0 (initial)
- `totalTasks`: Count of all tasks across all groups
- `completedTasks`: 0 (initial)

### Step 6: Update spec-meta.json

Update `agent-os/specs/[this-spec]/spec-meta.json`:

1. Set `status` to `"tasked"`
2. Set `taskedAt` to current ISO timestamp
3. Set `files.hasTasks` to `true`

### ID Assignment Rules

- **Task Group IDs**: `tg-001`, `tg-002`, etc.
- **Task IDs**: `task-001`, `task-002`, etc. (globally unique within the spec)
- **Subtask IDs**: `subtask-001`, `subtask-002`, etc. (globally unique within the spec)
- IDs are permanent and should never be reused

### Layer Types

Use these values for the `layer` field:
- `database` - Models, migrations, database operations
- `api` - API endpoints, controllers, services
- `frontend` - UI components, pages, styling
- `testing` - Test coverage review and gap filling
- `infrastructure` - Config, deployment, CI/CD
- `integration` - Third-party services, external APIs
- `other` - Anything that doesn't fit above

### Dependencies

- Use task group IDs in the `dependencies` array
- Example: `"dependencies": ["tg-001"]` means this group depends on tg-001
- All dependencies must be completed before a group can start

### Important Constraints

- **Create tasks that are specific and verifiable**
- **Verify spec completeness for refactoring tasks** - Run independent grep searches to find all affected files, not just those mentioned in spec
- **Flag gaps discovered** - If your impact analysis finds files not in the spec, document them and create task groups to address them
- **Group related tasks by architectural layer**
- **Limit test writing during development**: 2-8 focused tests per task group
- **Use explicit dependencies** rather than relying on ordering
- **Include acceptance criteria** for each task group
- **Reference visual assets** if visuals are available in planning/visuals/
- **Task count**: Aim for 3-10 tasks per task group
