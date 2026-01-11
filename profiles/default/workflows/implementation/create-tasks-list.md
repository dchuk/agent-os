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

### Step 2: Create tasks.json

Generate `agent-os/specs/[this-spec]/tasks.json` following the schema at `agent-os/schemas/tasks.schema.json`.

```json
{
  "schemaVersion": "1.0.0",
  "specId": "[SPEC_FOLDER_NAME]",
  "specTitle": "[FEATURE_NAME from spec.md]",
  "roadmapItemId": "[FROM spec-meta.json or null]",
  "createdAt": "[CURRENT_ISO_TIMESTAMP]",
  "lastUpdated": "[CURRENT_ISO_TIMESTAMP]",
  "status": "pending",
  "summary": {
    "totalTaskGroups": 0,
    "completedTaskGroups": 0,
    "totalTasks": 0,
    "completedTasks": 0
  },
  "taskGroups": []
}
```

### Step 3: Populate Task Groups

For each logical grouping of work, create a task group:

```json
{
  "id": "tg-001",
  "name": "Database Layer",
  "layer": "database",
  "description": "Create data models and migrations for [feature]",
  "dependencies": [],
  "status": "pending",
  "assignedAgent": null,
  "acceptanceCriteria": [
    "Models pass validation tests",
    "Migrations run successfully",
    "Associations work correctly"
  ],
  "startedAt": null,
  "completedAt": null,
  "tasks": []
}
```

### Step 4: Populate Tasks and Subtasks

For each task within a group:

```json
{
  "id": "task-001",
  "title": "Create User model with validations",
  "status": "pending",
  "notes": null,
  "subtasks": [
    {
      "id": "subtask-001",
      "title": "Write 2-8 focused tests for User model",
      "status": "pending",
      "details": [
        "Test primary validation rules",
        "Test key associations",
        "Skip exhaustive edge case coverage"
      ],
      "notes": null
    },
    {
      "id": "subtask-002",
      "title": "Implement User model",
      "status": "pending",
      "details": [
        "Fields: email, name, created_at, updated_at",
        "Validations: email format, name presence",
        "Reuse pattern from existing models"
      ],
      "notes": null
    }
  ]
}
```

### Step 5: Update Summary Statistics

After populating all task groups, calculate and update the `summary` object:

```json
"summary": {
  "totalTaskGroups": [COUNT_OF_TASK_GROUPS],
  "completedTaskGroups": 0,
  "totalTasks": [COUNT_OF_ALL_TASKS_ACROSS_GROUPS],
  "completedTasks": 0
}
```

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
- **Group related tasks by architectural layer**
- **Limit test writing during development**: 2-8 focused tests per task group
- **Use explicit dependencies** rather than relying on ordering
- **Include acceptance criteria** for each task group
- **Reference visual assets** if visuals are available in planning/visuals/
- **Task count**: Aim for 3-10 tasks per task group
