# Implement Tasks

Implement all tasks assigned to you and ONLY those task(s) that have been assigned to you.

## Implementation Process

### Step 1: Load Context

1. Read `agent-os/specs/[this-spec]/tasks.json` to understand the full task structure
2. Read `agent-os/specs/[this-spec]/spec.md` for requirements context
3. Read `agent-os/specs/[this-spec]/spec-meta.json` for roadmap linkage
4. Check `agent-os/specs/[this-spec]/planning/visuals/` for any visual references
5. Read `CLAUDE.md` from the project root (if exists) - contains project-specific rules, conventions, and requirements that you MUST follow
6. Check available skills in your system context (listed in `<available_skills>` section). Use the `Skill(skill_name)` tool to invoke relevant skills for your task (e.g., testing skills when writing tests). Skills contain important requirements you MUST follow.

### Step 2: Update Status to In-Progress

Update `tasks.json`:
1. Set the relevant task group's `status` to `"in-progress"`
2. Set `startedAt` to current ISO timestamp
3. Update `lastUpdated` at the root level

Update `spec-meta.json`:
1. If this is the first task group being implemented:
   - Set `status` to `"in-progress"`
   - Set `implementationStartedAt` to current ISO timestamp

Update `roadmap.json`:
1. If this is the first implementation work on this spec:
   - Find the linked roadmap item by `roadmapItemId`
   - Set `status` to `"in-progress"`
   - Set `startedAt` to current ISO timestamp
   - Update `lastUpdated` at the root level

### Step 3: Implement Tasks

For each task in the assigned task group(s):

1. Update the task's `status` to `"in-progress"` in tasks.json
2. Implement according to:
   - **Existing patterns** found in the codebase
   - **Specific notes** in spec.md, requirements.md, and tasks.json
   - **Visuals** in planning/visuals/ (if any)
   - **User Standards & Preferences** as defined in standards files
3. Update subtask statuses as you complete them
4. Add any relevant `notes` to tasks or subtasks for future reference
5. When task is complete, set `status` to `"completed"`

### Step 4: Track Findings During Implementation

As you implement, note any of the following for the findings capture phase:
- Build errors that required fixing and how you fixed them
- Configuration patterns you discovered
- Code patterns established in the codebase
- Performance considerations you encountered
- Testing patterns that worked well
- Gotchas or non-obvious behaviors

Keep a mental or temporary note of these for Step 7.

### Step 5: Self-Verify Your Work

1. Run ONLY the tests you've written (if any) and ensure they pass
2. IF your task involves user-facing UI and IF you have browser testing tools:
   - Open a browser and test the feature as a user would
   - Take screenshots and store in `agent-os/specs/[this-spec]/verification/screenshots/`
   - Analyze screenshots against requirements

### Step 6: Update Completion Status

When all tasks in a task group are complete:

Update `tasks.json`:
1. Set the task group's `status` to `"completed"`
2. Set `completedAt` to current ISO timestamp
3. Increment `summary.completedTaskGroups`
4. Update `summary.completedTasks` count
5. Update `lastUpdated`

If ALL task groups are now complete:

Update `tasks.json`:
1. Set root `status` to `"completed"`

Update `spec-meta.json`:
1. Set `status` to `"completed"`
2. Set `completedAt` to current ISO timestamp

Update `roadmap.json`:
1. Find the linked roadmap item
2. Set `status` to `"completed"`
3. Set `completedAt` to current ISO timestamp
4. Update `lastUpdated`

### Step 7: Capture Findings

After completing implementation (whether partial or full), capture any findings discovered:

1. Read `agent-os/product/findings.json` (create if doesn't exist)
2. For each finding worth capturing:

```json
{
  "id": "finding-[NEXT_NUMBER]",
  "category": "[appropriate-category]",
  "title": "[Short descriptive title]",
  "description": "[Detailed explanation]",
  "context": "[When/where this applies]",
  "recommendation": "[Actionable guidance]",
  "codeExample": "[Optional code snippet]",
  "antiPattern": "[Optional what NOT to do]",
  "relatedFiles": ["[relevant/file/paths]"],
  "sourceSpec": "[this-spec-id]",
  "discoveredAt": "[CURRENT_ISO_TIMESTAMP]",
  "lastConfirmedAt": "[CURRENT_ISO_TIMESTAMP]",
  "confirmedCount": 1,
  "confidence": "[low|medium|high]",
  "status": "active",
  "supersededBy": null,
  "archivedAt": null,
  "archivedReason": null
}
```

3. Before adding a new finding, check if a similar one exists:
   - If yes and still valid: increment `confirmedCount`, update `lastConfirmedAt`
   - If yes but needs updating: update the existing finding
   - If no: add as new finding

4. Update `findings.json`:
   - Add new findings to the `findings` array
   - Update `lastUpdated`

5. Update `spec-meta.json`:
   - Add any new finding IDs to `findingsGenerated` array

### Finding Categories Reference

- `build-config` - Build system, compilation, bundling issues
- `error-pattern` - Common errors and their solutions
- `code-pattern` - Established patterns in the codebase
- `dependency` - Package/library specific behaviors
- `performance` - Performance considerations
- `testing` - Testing patterns and gotchas
- `architecture` - Architectural decisions and constraints
- `tooling` - Development tooling configurations
- `security` - Security-related patterns
- `other` - Anything else worth noting

### Confidence Levels

- `low` - Encountered once, might be specific to this context
- `medium` - Encountered multiple times or seems broadly applicable
- `high` - Clearly established pattern, encountered consistently

## CRITICAL: Task Completion Rules

### Rule 1: A Task Is Complete ONLY When Actually Executed
- If a task says "Run tests" - you MUST execute the tests and see the output
- If a task says "Verify X works" - you MUST actually verify it
- Do NOT mark tasks as complete based on intent or assumption
- "I wrote the code" ≠ "task complete" - you must perform the actual action described

### Rule 2: Handle Missing Prerequisites
- If a task requires a running service (dev server, database) that is not running:
  - Start the service yourself (safe for parallel execution in isolated environments)
- If a task requires dependencies that are not installed:
  - Do NOT install them yourself (may conflict with parallel agents)
  - Report the blocker and keep task status as "pending" or "blocked"
  - Dependency installation is the responsibility of planning/setup phase
- If you cannot determine how to proceed, ask the user for guidance

### Rule 3: Task Groups Require All Tasks Complete
- A task group can ONLY have status "completed" when ALL its tasks have status "completed"
- Never mark a task group complete while leaving tasks incomplete

### Rule 4: TDD Phases Require Actual Test Execution
- If tasks specify TDD workflow:
  - RED phase: Tests must be written AND executed to verify they fail
  - GREEN phase: Tests must be executed AND pass
- Do NOT mark TDD tasks complete without actual test execution output

### Rule 5: Verification Tasks Require Evidence
- If a task says "Manual verification" or "Verify in browser":
  - Actually perform the verification using available tools
  - Take screenshots as evidence when possible
  - Store evidence in `verification/screenshots/`
- Do NOT mark verification tasks complete without performing verification

### Rule 6: Incomplete Tasks Must Stay Incomplete
- If you cannot complete a task after attempting to resolve blockers:
  - Keep the task's status as "pending" or set to "blocked"
  - Add a note explaining what you tried and what blocked you
  - NEVER set status to "completed" if you did not actually complete it

## Important Constraints

- **Always update JSON files** - Keep tasks.json, spec-meta.json, and roadmap.json in sync
- **Track status transitions** - Update status fields and timestamps as work progresses
- **Capture findings** - Don't lose institutional knowledge gained during implementation
- **Verify before marking complete** - Run tests and verify functionality
- **Follow task completion rules** - Never mark tasks complete without actual execution
