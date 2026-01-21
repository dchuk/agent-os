# Assessment: Roadmap-Driven Spec Workflow with Continuous Alignment

**Date:** 2026-01-21
**Prepared for:** Product workflow optimization analysis
**Agent OS Version:** 3.0.0
**Status:** Revised with batch flow design

---

## Executive Summary

This assessment evaluates how well Agent OS can support a workflow where:
1. A product roadmap is created upfront
2. Specs are created for ALL roadmap items before implementation begins
3. An AI agent iterates through each spec's tasks sequentially
4. As work progresses, future tasks are "aligned" to stay on track
5. As specs are completed, subsequent spec creation factors in prior work for consistency

**Overall Assessment: 70% Ready** - The framework has strong foundations but lacks explicit mechanisms for cross-spec alignment and batch spec processing.

**Revised Design Included:** This document now contains a complete "Batch Flow with Checkpoints" design that maximizes parallelism while maintaining coordination through explicit alignment reviews.

---

## Current Capabilities Analysis

### What Works Well (Strengths)

#### 1. Roadmap Schema with Dependencies
**Location:** `profiles/default/schemas/roadmap.schema.json:64-70`

The roadmap schema supports explicit dependencies between items:
```json
{
  "dependencies": {
    "type": "array",
    "items": { "type": "string", "pattern": "^roadmap-[0-9]{3,}$" }
  }
}
```

**Rating:** Excellent
This allows topological ordering of roadmap items and could drive sequential spec creation in dependency order.

#### 2. Bidirectional Linking
**Locations:**
- `roadmap.schema.json:71-74` - `specPath` field
- `spec-meta.schema.json:20-25` - `roadmapItemId` field

Every spec knows its roadmap item, and every roadmap item knows its spec. This enables:
- Tracking which roadmap items have specs
- Querying spec status from roadmap view
- Maintaining consistency during updates

**Rating:** Excellent

#### 3. Structured Spec Lifecycle
**Location:** `profiles/default/workflows/specification/`

Clear progression: `drafting → shaped → specced → tasked → in-progress → completed`

Each phase has:
- Dedicated workflow document
- Clear inputs/outputs
- Status tracking via `spec-meta.json`

**Rating:** Excellent

#### 4. Task Completion Rules with Actual Execution Verification
**Location:** `workflows/implementation/implement-tasks.md:137-176`

Strict rules prevent false completion:
- Tasks must be actually executed (not just written)
- TDD phases require real test runs
- Verification tasks require evidence (screenshots)
- Blocked tasks stay incomplete with notes

**Rating:** Excellent - Critical for maintaining roadmap integrity

#### 5. Findings System for Institutional Knowledge
**Location:** `profiles/default/schemas/findings.schema.json`

Captures patterns discovered during implementation:
- Build configurations
- Error patterns
- Code patterns
- Architectural decisions

Findings have confidence levels, source specs, and confirmation counts.

**Rating:** Good - Foundation exists but not fully leveraged during spec creation

#### 6. Impact Analysis for Refactoring
**Location:** `workflows/specification/write-spec.md:47-93`

Comprehensive grep-based search to find ALL affected code, including:
- Duplicate definitions across packages
- Hardcoded values
- Related mappings and transformations

**Rating:** Good - Works for single specs, not cross-spec coordination

---

### Gaps for Target Workflow

#### Gap 1: No Bulk Spec Creation Workflow
**Severity:** High

**Current State:**
- Specs are created one at a time via `/shape-spec → /write-spec`
- Each spec creation is an isolated session
- No command to batch-process roadmap items

**What's Missing:**
- A `/batch-create-specs` command that iterates through all `status: "planned"` items
- Queue management for processing multiple specs
- Progress tracking across bulk operations

#### Gap 2: No Cross-Spec Alignment During Creation
**Severity:** High

**Current State:**
The `research-spec.md` workflow reads:
- `agent-os/product/mission.md` (product context)
- `agent-os/product/roadmap.json` (overall roadmap)
- `agent-os/product/tech-stack.md` (technical choices)

**What's Missing:**
It does NOT read:
- Other spec documents (`agent-os/specs/*/spec.md`)
- Other specs' task breakdowns (`agent-os/specs/*/tasks.json`)
- Inter-spec dependencies or shared components

This means Spec B cannot reference decisions made in Spec A unless the agent remembers them from conversation context (which is lost between sessions).

#### Gap 3: No "Alignment" Phase During Task Execution
**Severity:** Medium

**Current State:**
Tasks are executed as defined in `tasks.json` with no re-evaluation.

**What's Missing:**
- A mechanism to re-read future task groups after completing one
- A "drift check" that compares implementation reality vs. spec assumptions
- An "alignment pass" that updates downstream specs/tasks based on learnings

#### Gap 4: Findings Not Consulted During Spec Creation
**Severity:** Medium

**Current State:**
- Findings are captured after implementation (Step 7 in `implement-tasks.md`)
- Findings are reviewed periodically via `/review-findings`
- Findings are NOT read during `research-spec` or `write-spec`

**What's Missing:**
- A step in `research-spec.md` to read `findings.json` and apply relevant patterns
- A "findings consultation" step in `write-spec.md` to ensure consistency
- Auto-injection of relevant findings into spec context

#### Gap 5: No Automated Roadmap Queue Processing
**Severity:** Medium

**Current State:**
- Roadmap exists with dependencies and priorities
- Processing is manual: user runs commands for each item
- No orchestrator that automatically picks the next ready item

**What's Missing:**
- A "roadmap processor" that:
  1. Finds items where all dependencies are `completed`
  2. Picks highest priority ready item
  3. Initiates spec creation/implementation
  4. Loops until roadmap is complete
- Session continuity between specs

---

## Revised Batch Flow Design

This section presents a refined workflow that maximizes parallelism while maintaining coordination through explicit alignment checkpoints.

### Design Philosophy

**"Funnel with Checkpoints"** - Front-load human input, batch parallel operations, insert explicit alignment reviews before proceeding to next phase.

Key principles:
1. **Human input is front-loaded** - All creative/judgment work happens upfront with full context
2. **Parallelism where safe** - Spec writing and task creation are independent once inputs gathered
3. **Explicit checkpoints** - Two alignment reviews catch drift before it compounds
4. **Risk-based autonomy** - Agent doesn't interrupt for trivial fixes during execution

### Complete Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     BATCH FLOW WITH CHECKPOINTS                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ PHASE 1: SHAPING (Sequential)                                    │   │
│  │ ─────────────────────────────────────────────────────────────── │   │
│  │ User answers Q&A for each roadmap item in order.                 │   │
│  │ Human judgment preserved. Context accumulates.                   │   │
│  │                                                                  │   │
│  │   ┌──────┐     ┌──────┐     ┌──────┐     ┌──────┐              │   │
│  │   │ Q&A  │ ──▶ │ Q&A  │ ──▶ │ Q&A  │ ──▶ │ Q&A  │              │   │
│  │   │Item 1│     │Item 2│     │Item 3│     │Item N│              │   │
│  │   └──────┘     └──────┘     └──────┘     └──────┘              │   │
│  │                                                                  │   │
│  │   Optimization: Group related items to reduce repetitive Qs     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                  │                                      │
│                                  ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ PHASE 2: SPEC WRITING (Parallel)                                 │   │
│  │ ─────────────────────────────────────────────────────────────── │   │
│  │ All specs written simultaneously. Each has full shaped context.  │   │
│  │                                                                  │   │
│  │   ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐                       │   │
│  │   │Write │  │Write │  │Write │  │Write │                       │   │
│  │   │Spec 1│  │Spec 2│  │Spec 3│  │Spec N│                       │   │
│  │   └──────┘  └──────┘  └──────┘  └──────┘                       │   │
│  │       │         │         │         │                           │   │
│  │       └─────────┴─────────┴─────────┘                           │   │
│  │                     │                                            │   │
│  └─────────────────────│────────────────────────────────────────────┘   │
│                        ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ CHECKPOINT 1: SPEC ALIGNMENT REVIEW                              │   │
│  │ ─────────────────────────────────────────────────────────────── │   │
│  │ Agent compares ALL specs. Identifies conflicts and drift.        │   │
│  │ User reviews findings and approves/adjusts.                      │   │
│  │                                                                  │   │
│  │   ┌─────────────────────────────────────────────────────────┐   │   │
│  │   │ Alignment Agent reads all specs                          │   │   │
│  │   │  ├─ Naming conflicts?                                    │   │   │
│  │   │  ├─ API inconsistencies?                                 │   │   │
│  │   │  ├─ Data model drift?                                    │   │   │
│  │   │  ├─ Shared component divergence?                         │   │   │
│  │   │  ├─ Dependency ordering issues?                          │   │   │
│  │   │  └─ Scope overlap/duplication?                           │   │   │
│  │   └─────────────────────────────────────────────────────────┘   │   │
│  │                         │                                        │   │
│  │                         ▼                                        │   │
│  │   ┌─────────────────────────────────────────────────────────┐   │   │
│  │   │ User reviews: approve / request changes / provide input  │   │   │
│  │   └─────────────────────────────────────────────────────────┘   │   │
│  │                         │                                        │   │
│  │                         ▼                                        │   │
│  │   ┌─────────────────────────────────────────────────────────┐   │   │
│  │   │ Agent applies approved changes + cascade check           │   │   │
│  │   └─────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                  │                                      │
│                                  ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ PHASE 3: TASK CREATION (Parallel)                                │   │
│  │ ─────────────────────────────────────────────────────────────── │   │
│  │ All task lists created simultaneously from aligned specs.        │   │
│  │                                                                  │   │
│  │   ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐                       │   │
│  │   │Tasks │  │Tasks │  │Tasks │  │Tasks │                       │   │
│  │   │Spec 1│  │Spec 2│  │Spec 3│  │Spec N│                       │   │
│  │   └──────┘  └──────┘  └──────┘  └──────┘                       │   │
│  │       │         │         │         │                           │   │
│  │       └─────────┴─────────┴─────────┘                           │   │
│  │                     │                                            │   │
│  └─────────────────────│────────────────────────────────────────────┘   │
│                        ▼                                                │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ CHECKPOINT 2: TASK ALIGNMENT REVIEW                              │   │
│  │ ─────────────────────────────────────────────────────────────── │   │
│  │ Agent compares ALL task lists. Validates ordering & deps.        │   │
│  │ User reviews findings and approves/adjusts.                      │   │
│  │                                                                  │   │
│  │   ┌─────────────────────────────────────────────────────────┐   │   │
│  │   │ Alignment Agent reads all tasks.json                     │   │   │
│  │   │  ├─ Cross-spec task dependencies correct?                │   │   │
│  │   │  ├─ Shared infrastructure tasks deduplicated?            │   │   │
│  │   │  ├─ Execution order respects dependencies?               │   │   │
│  │   │  ├─ Integration points identified?                       │   │   │
│  │   │  └─ Effort estimates reasonable?                         │   │   │
│  │   └─────────────────────────────────────────────────────────┘   │   │
│  │                         │                                        │   │
│  │                         ▼                                        │   │
│  │   ┌─────────────────────────────────────────────────────────┐   │   │
│  │   │ User reviews: approve / request changes / provide input  │   │   │
│  │   └─────────────────────────────────────────────────────────┘   │   │
│  │                         │                                        │   │
│  │                         ▼                                        │   │
│  │   ┌─────────────────────────────────────────────────────────┐   │   │
│  │   │ Agent applies approved changes + cascade check           │   │   │
│  │   └─────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                  │                                      │
│                                  ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ PHASE 4: EXECUTION (Sequential with Smart Alignment)             │   │
│  │ ─────────────────────────────────────────────────────────────── │   │
│  │ Execute specs in dependency order. Monitor for drift.            │   │
│  │ Risk-based autonomy: agent resolves low-risk, escalates high.    │   │
│  │                                                                  │   │
│  │   FOR each spec in dependency order:                             │   │
│  │   ┌──────────────────────────────────────────────────────────┐  │   │
│  │   │  Execute task groups                                      │  │   │
│  │   │       │                                                   │  │   │
│  │   │       ▼                                                   │  │   │
│  │   │  Drift detected?                                          │  │   │
│  │   │       │                                                   │  │   │
│  │   │       ├─▶ LOW RISK ──▶ Agent resolves, logs decision     │  │   │
│  │   │       │                                                   │  │   │
│  │   │       ├─▶ MEDIUM ────▶ Agent resolves, notifies after    │  │   │
│  │   │       │                                                   │  │   │
│  │   │       └─▶ HIGH RISK ─▶ STOP, ask user for direction      │  │   │
│  │   │                                                           │  │   │
│  │   │  Update downstream specs/tasks if needed                  │  │   │
│  │   │  Capture findings                                         │  │   │
│  │   │  Mark spec complete                                       │  │   │
│  │   └──────────────────────────────────────────────────────────┘  │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Phase Details

#### Phase 1: Sequential Shaping

**Purpose:** Gather requirements with human judgment for each roadmap item.

**Why Sequential:**
- Each item may inform questions for subsequent items
- User builds mental model progressively
- Allows grouping related items to reduce repetitive questions

**Optimization - Group Related Items:**

Instead of purely sequential, batch related roadmap items:

```
Round 1: Auth-related items (login, signup, password reset)
  → Q&A covers shared auth decisions once
  → Output: requirements for 3 items

Round 2: Dashboard items (metrics, charts, exports)
  → Q&A covers shared data visualization decisions
  → Output: requirements for 3 items

Round 3: Standalone items
  → Individual Q&A as needed
  → Output: requirements for remaining items
```

**Command:** `/batch-shape`

#### Phase 2: Parallel Spec Writing

**Purpose:** Convert all shaped requirements into full specifications simultaneously.

**Why Parallel:**
- Each spec writer has complete requirements from shaping
- No dependencies between spec writing operations
- Significant time savings (N specs in time of 1)

**Context Injection:**
Each parallel spec writer receives:
- Its own requirements.md
- Product mission, tech stack
- All OTHER requirements.md files (for cross-reference)
- Findings.json (institutional knowledge)

**Command:** `/parallel-write-specs`

#### Checkpoint 1: Spec Alignment Review

**Purpose:** Catch conflicts and drift BEFORE task creation.

**What the Alignment Agent Checks:**

| Category | What to Check | Example Issue |
|----------|---------------|---------------|
| **Naming Conflicts** | Same name, different meaning | Two specs define `UserProfile` model differently |
| **API Inconsistency** | Incompatible interfaces | Spec A: `GET /users/:id`, Spec B: `GET /user/:id` |
| **Data Model Drift** | Schema conflicts | Spec A: `user.email` (string), Spec B: `user.emails` (array) |
| **Shared Components** | Same component, different APIs | Both use `<Button>` but expect different props |
| **Dependency Ordering** | Wrong sequence declared | Spec B depends on A but roadmap doesn't reflect |
| **Scope Overlap** | Duplicate work | Both specs implement user notifications |

**Output Format:**
```markdown
## Spec Alignment Report

### Conflicts Found: 3

#### 1. API Naming Inconsistency (HIGH)
- **Specs affected:** user-auth, user-profile
- **Issue:** Different URL patterns for user endpoints
  - user-auth: `POST /users/login`
  - user-profile: `GET /user/:id` (singular)
- **Recommendation:** Standardize on `/users/` (plural)
- **Files to update:** user-profile/spec.md

#### 2. Shared Component Divergence (MEDIUM)
- **Specs affected:** dashboard-metrics, dashboard-charts
- **Issue:** Both define `<DataCard>` with different props
- **Recommendation:** Consolidate into single component definition
- **Files to update:** Both specs, add to shared-components spec

#### 3. Scope Overlap (LOW)
- **Specs affected:** user-notifications, dashboard-alerts
- **Issue:** Both mention toast notifications
- **Recommendation:** Clarify ownership - notifications owns toasts
- **Files to update:** dashboard-alerts/spec.md (remove toast section)

### No Issues Found:
- Dependency ordering ✓
- Data models ✓
- Naming conventions ✓

### Awaiting User Decision:
[ ] Approve all recommendations
[ ] Approve with modifications: ___
[ ] Reject, keep as-is
```

**User Interaction:**
- User reviews report
- Approves, modifies, or rejects each recommendation
- Agent applies approved changes with cascade check

**Cascade Check:**
When a change is approved, automatically verify it doesn't break other specs:
```
User approves: "Rename UserProfile to AccountProfile everywhere"
  ↓
Cascade check: "This affects Specs 2, 4, 7. Updating all automatically."
  ↓
Quick re-validation: "All 3 specs updated consistently. ✓"
```

**Command:** `/align-specs`

#### Phase 3: Parallel Task Creation

**Purpose:** Convert all aligned specs into task lists simultaneously.

**Why Parallel:**
- Specs are now aligned and consistent
- Task creation is independent per spec
- Significant time savings

**Command:** `/parallel-create-tasks`

#### Checkpoint 2: Task Alignment Review

**Purpose:** Validate cross-spec task dependencies and execution order.

**What the Alignment Agent Checks:**

| Category | What to Check | Example Issue |
|----------|---------------|---------------|
| **Cross-Spec Dependencies** | Task A needs Task B from different spec | Spec 2 Task 3 needs Spec 1 Task 5 complete first |
| **Infrastructure Deduplication** | Same setup in multiple specs | Multiple specs create "setup database" task |
| **Execution Order** | Respects roadmap dependencies | Spec B tasks scheduled before Spec A completes |
| **Integration Points** | Where specs connect | API consumer tasks align with API provider tasks |
| **Effort Sanity** | Reasonable estimates | One spec has 50 XL tasks, another has 2 XS |

**Output Format:**
```markdown
## Task Alignment Report

### Cross-Spec Dependencies Identified: 2

#### 1. API Dependency
- **Consumer:** user-profile/tasks.json → Task Group 2, Task 1
- **Provider:** user-auth/tasks.json → Task Group 3, Task 4
- **Action:** Add explicit dependency link
- **Execution order:** user-auth must complete TG3 before user-profile starts TG2

#### 2. Shared Infrastructure
- **Duplicate:** "Setup Redis for caching" appears in 3 specs
- **Action:** Consolidate into infrastructure spec, remove from others

### Recommended Execution Order:
1. infrastructure (no deps)
2. user-auth (depends on infrastructure)
3. user-profile (depends on user-auth)
4. dashboard-metrics (depends on user-auth)
5. dashboard-charts (depends on dashboard-metrics)

### Awaiting User Decision:
[ ] Approve execution order
[ ] Approve dependency additions
[ ] Approve deduplication
```

**Command:** `/align-tasks`

#### Phase 4: Execution with Smart Alignment

**Purpose:** Execute tasks while monitoring for drift and handling misalignment intelligently.

**Risk Classification for Alignment Decisions:**

| Risk Level | Criteria | Agent Action |
|------------|----------|--------------|
| **Low** | Naming/formatting only, no behavior change | Resolve silently, log decision |
| **Low** | Additive change (new optional field/param) | Resolve silently, log decision |
| **Medium** | Changes affect current spec only | Resolve, notify user after completion |
| **Medium** | Minor deviation from spec (same intent) | Resolve, notify user after completion |
| **High** | Changes affect multiple specs | STOP, ask user before proceeding |
| **High** | Changes to core abstractions (auth, data layer) | STOP, ask user before proceeding |
| **High** | Contradicts explicit user decision from shaping | STOP, ask user before proceeding |
| **Critical** | Security implications | STOP, ask user before proceeding |

**Drift Detection Triggers:**
- Implementation creates different API than spec described
- New dependency discovered not in tasks.json
- Task cannot be completed as specified
- Test failures reveal spec assumption was wrong
- Downstream task references something that doesn't exist

**Alignment Resolution Flow:**
```
Drift Detected
     │
     ▼
Classify Risk Level
     │
     ├─▶ LOW: Resolve + Log
     │        │
     │        ▼
     │   Continue execution
     │
     ├─▶ MEDIUM: Resolve + Queue Notification
     │        │
     │        ▼
     │   Continue execution
     │   Notify user at spec completion
     │
     └─▶ HIGH/CRITICAL: Stop
              │
              ▼
         Present to user:
         - What was expected
         - What actually happened
         - Impact assessment
         - Recommended resolution
              │
              ▼
         User decides:
         - Approve recommendation
         - Provide alternative
         - Pause roadmap
              │
              ▼
         Apply decision + cascade check
              │
              ▼
         Continue execution
```

**Command:** `/execute-roadmap`

### New Components Required

#### New Commands

| Command | Purpose | Phase |
|---------|---------|-------|
| `/batch-shape` | Orchestrate sequential Q&A for multiple roadmap items | 1 |
| `/parallel-write-specs` | Write all shaped specs in parallel | 2 |
| `/align-specs` | Compare all specs, report conflicts, apply changes | Checkpoint 1 |
| `/parallel-create-tasks` | Create all task lists in parallel | 3 |
| `/align-tasks` | Compare all tasks, validate ordering, apply changes | Checkpoint 2 |
| `/execute-roadmap` | Sequential execution with smart alignment | 4 |

#### New Agent

**Alignment Reviewer Agent** (`alignment-reviewer.md`)

```yaml
---
name: alignment-reviewer
description: Reviews multiple specs or task lists for conflicts and drift
capabilities:
  - Cross-document comparison
  - Conflict detection
  - Dependency analysis
  - Change recommendation
  - Cascade impact assessment
---
```

Responsibilities:
- Read multiple specs or task files
- Apply explicit checklist of alignment criteria
- Output structured diff/conflict report
- Apply approved changes consistently
- Verify changes don't introduce new conflicts (cascade check)

#### Schema Additions

**Addition to `spec-meta.schema.json`:**

```json
{
  "alignmentStatus": {
    "type": "string",
    "enum": ["pending", "reviewed", "approved", "needs-revision"],
    "description": "Status of cross-spec alignment review"
  },
  "alignmentReviewedAt": {
    "type": "string",
    "format": "date-time",
    "description": "When alignment was last reviewed"
  },
  "alignmentNotes": {
    "type": "array",
    "items": { "type": "string" },
    "description": "Notes from alignment review"
  },
  "relatedSpecs": {
    "type": "array",
    "items": { "type": "string" },
    "description": "Other spec IDs this spec has dependencies or conflicts with"
  }
}
```

**Addition to `tasks.schema.json`:**

```json
{
  "crossSpecDependencies": {
    "type": "array",
    "items": {
      "type": "object",
      "properties": {
        "specId": { "type": "string" },
        "taskGroupId": { "type": "string" },
        "taskId": { "type": "string" },
        "type": {
          "type": "string",
          "enum": ["blocks", "blocked-by", "related"]
        }
      }
    },
    "description": "Tasks in other specs that this task depends on or blocks"
  }
}
```

**New file: `alignment-report.schema.json`:**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Alignment Report",
  "type": "object",
  "properties": {
    "reportId": { "type": "string" },
    "reportType": {
      "type": "string",
      "enum": ["spec-alignment", "task-alignment", "execution-drift"]
    },
    "createdAt": { "type": "string", "format": "date-time" },
    "specsReviewed": {
      "type": "array",
      "items": { "type": "string" }
    },
    "conflicts": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "severity": { "type": "string", "enum": ["low", "medium", "high", "critical"] },
          "category": { "type": "string" },
          "description": { "type": "string" },
          "specsAffected": { "type": "array", "items": { "type": "string" } },
          "recommendation": { "type": "string" },
          "userDecision": {
            "type": "string",
            "enum": ["pending", "approved", "rejected", "modified"]
          },
          "userNotes": { "type": "string" },
          "resolvedAt": { "type": "string", "format": "date-time" }
        }
      }
    },
    "executionOrder": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Recommended spec execution order"
    },
    "status": {
      "type": "string",
      "enum": ["pending-review", "approved", "changes-applied"]
    }
  }
}
```

### Implementation Phases

#### Phase A: Foundation (First)
1. Create `alignment-reviewer.md` agent
2. Add schema fields to `spec-meta.schema.json` and `tasks.schema.json`
3. Create `alignment-report.schema.json`

#### Phase B: Checkpoints (Second)
1. Create `/align-specs` command and workflow
2. Create `/align-tasks` command and workflow
3. Test checkpoint flow manually

#### Phase C: Batch Operations (Third)
1. Create `/batch-shape` command (wraps existing shape workflow)
2. Create `/parallel-write-specs` command
3. Create `/parallel-create-tasks` command

#### Phase D: Execution (Fourth)
1. Create `/execute-roadmap` command
2. Implement risk classification logic
3. Implement drift detection hooks
4. Test full end-to-end flow

---

## Recommendations for Iteration

### Priority 1: Cross-Spec Context in Spec Creation

**Modification to `research-spec.md` (Step 2):**

Add a new sub-step after reading product context:

```markdown
### Step 2.5: Analyze Related Specs

Before generating questions, review specs for related or dependent roadmap items:

1. **Read Dependency Specs**: For each item in the current roadmap item's `dependencies`:
   - Read `agent-os/specs/[dependency-specPath]/spec.md`
   - Note: Shared components, APIs, data models
   - Note: Decisions that constrain this spec

2. **Read Specs with Same Tags**: For roadmap items with overlapping `tags`:
   - Identify shared concerns (e.g., multiple "auth" tagged items)
   - Look for patterns to maintain consistency

3. **Read Completed Specs (recent 3-5)**: To understand established patterns:
   - Code organization decisions
   - Component naming conventions
   - API design patterns

Document findings in requirements.md under "## Related Specs Context"
```

**Estimated Effort:** Small
**Files to Modify:** `research-spec.md`, `write-spec.md`

---

### Priority 2: Findings Consultation During Spec Creation

**Modification to `write-spec.md` (new Step 1.5):**

```markdown
### Step 1.5: Consult Institutional Knowledge

Before searching for reusable code:

1. Read `agent-os/product/findings.json`
2. Filter findings by:
   - Categories relevant to this spec (e.g., "code-pattern", "architecture")
   - `status: "active"`
   - `confidence: "medium"` or `"high"`
3. For each relevant finding:
   - Consider how `recommendation` applies to this spec
   - Note constraints or patterns to follow
4. Document applied findings in spec.md under "## Applied Findings"
```

**Estimated Effort:** Small
**Files to Modify:** `write-spec.md`, spec.md template

---

### Priority 3: Batch Spec Creation Command

**New Command: `/batch-spec-roadmap`**

Create `profiles/default/commands/batch-spec-roadmap/batch-spec-roadmap.md`:

```markdown
# Batch Create Specs for Roadmap

Process all `planned` roadmap items in dependency order.

## Workflow

### Step 1: Load Roadmap
Read `agent-os/product/roadmap.json` and filter to `status: "planned"`.

### Step 2: Topological Sort
Order items by dependencies (items with no/completed dependencies first).

### Step 3: Process Queue
For each item in order:
1. Check dependencies are `specced` or `completed`
2. If ready:
   - Run spec initialization
   - Run spec research (with cross-spec context)
   - Run spec writing
   - Run spec verification
   - Update roadmap status to `specced`
3. If blocked:
   - Note blocker and continue to next item

### Step 4: Summary Report
Output:
- Specs created: [list]
- Specs blocked: [list with reasons]
- Remaining planned items: [count]
```

**Estimated Effort:** Medium
**Files to Create:** New command folder and workflow

---

### Priority 4: Task Alignment Pass

**New Workflow: `workflows/implementation/align-future-tasks.md`**

```markdown
# Align Future Tasks

After completing a task group, review and adjust upcoming work.

## When to Run
- After each task group completion
- Before starting a new task group

## Workflow

### Step 1: Capture Implementation Reality
Document what actually happened vs. spec assumptions:
- APIs created (names, signatures)
- Components built (names, props)
- Data models defined (schemas)
- Unexpected discoveries

### Step 2: Review Downstream Task Groups
For each pending task group in current spec:
- Check if assumptions still hold
- Flag tasks referencing things that changed
- Update task notes with corrections

### Step 3: Review Downstream Specs
For specs dependent on current roadmap item:
- Read their spec.md
- Flag sections that may need updates
- Add notes to spec-meta.json: `alignmentNeeded: true`

### Step 4: Output Alignment Report
```
## Alignment Check

### Current Implementation
- Created: [list of artifacts]
- Diverged from spec: [list if any]

### Downstream Impact
- Task groups to review: [list]
- Specs potentially affected: [list]

### Recommended Actions
- [specific updates needed]
```
```

**Estimated Effort:** Medium
**Files to Create:** New workflow, schema update for `alignmentNeeded`

---

### Priority 5: Roadmap Queue Processor

**New Command: `/process-roadmap`**

This is a meta-orchestrator that runs the full lifecycle for roadmap items:

```markdown
# Process Roadmap Autonomously

Execute the roadmap from current state to completion.

## Modes
- `spec-only`: Create specs for all planned items, stop before implementation
- `full`: Spec and implement all items
- `next`: Process only the next ready item

## Workflow

### Spec-Only Mode
1. Run `/batch-spec-roadmap`
2. Report completion

### Full Mode
Loop until no `planned` or `specced` items remain:
1. Find highest-priority item where:
   - All dependencies are `completed`
   - Status is `specced` or `planned`
2. If `planned`: Run spec creation workflow
3. If `specced`: Run `/create-tasks` then `/implement-tasks`
4. Run alignment pass
5. Update findings
6. Loop

### Next Mode
1. Find single next ready item
2. Run appropriate workflow
3. Report and exit
```

**Estimated Effort:** Large
**Files to Create:** New command, potentially a state machine for session continuity

---

## Implementation Roadmap for Improvements

### Phase 1: Low-Hanging Fruit (Week 1)
1. Add cross-spec context to `research-spec.md`
2. Add findings consultation to `write-spec.md`
3. Update spec.md template with new sections

### Phase 2: Batch Processing (Week 2)
1. Create `/batch-spec-roadmap` command
2. Implement topological sort logic
3. Add progress tracking

### Phase 3: Alignment System (Week 3)
1. Create `align-future-tasks.md` workflow
2. Add `alignmentNeeded` to spec-meta schema
3. Integrate alignment into `implement-tasks.md`

### Phase 4: Autonomous Processing (Week 4+)
1. Create `/process-roadmap` command
2. Design session continuity strategy
3. Add comprehensive error recovery

---

## How Well It Would Work Today (Without Changes)

### Scenario: 10-item roadmap, batch spec then batch implement

**What Would Work:**
1. Creating the roadmap with dependencies
2. Creating specs one-by-one (manually triggered)
3. Each spec would be well-structured with tasks
4. Implementation would track completion accurately
5. Findings would accumulate over time

**What Would Be Problematic:**
1. Spec 5 wouldn't know about decisions made in Spec 2
2. If Spec 3's implementation changes an API, Spec 7 (which depends on it) wouldn't auto-update
3. You'd need to manually run commands for each spec (~4 commands per spec)
4. No automatic queue processing
5. Findings wouldn't inform later spec creation

**Risk Level:** Medium
Inconsistencies could creep in between specs. An agent with good conversation memory could mitigate this within a single session, but across sessions, drift would occur.

### Mitigation Today (Without Framework Changes)

1. **Keep everything in one long session** - The agent's context will carry forward
2. **Manually reference prior specs** - Tell the agent "read specs X, Y, Z before starting"
3. **Create an alignment checklist** - After each spec, manually check for impacts
4. **Use findings aggressively** - Run `/review-findings` and manually inject into prompts

---

## Conclusion

Agent OS v3.0.0 provides a solid foundation with:
- Strong data structures (JSON schemas)
- Good lifecycle tracking
- Bidirectional linking
- Quality gates (verification workflows)

The main gaps are **cross-spec awareness** and **automated batch processing**. These can be addressed with the Revised Batch Flow Design documented above.

### Summary: Batch Flow with Checkpoints

The revised workflow maximizes efficiency while maintaining coordination:

| Phase | Mode | Purpose |
|-------|------|---------|
| 1. Shaping | Sequential | Preserve human judgment, accumulate context |
| 2. Spec Writing | Parallel | Efficiency - all specs written at once |
| Checkpoint 1 | Alignment Review | Catch conflicts before task creation |
| 3. Task Creation | Parallel | Efficiency - all tasks created at once |
| Checkpoint 2 | Alignment Review | Validate cross-spec dependencies |
| 4. Execution | Sequential | Risk-based autonomy, smart drift handling |

### Implementation Path

| Phase | Components | Effort |
|-------|------------|--------|
| A. Foundation | Alignment agent, schema updates | Small |
| B. Checkpoints | `/align-specs`, `/align-tasks` | Medium |
| C. Batch Ops | `/batch-shape`, `/parallel-write-specs`, `/parallel-create-tasks` | Medium |
| D. Execution | `/execute-roadmap` with drift detection | Large |

### Readiness Assessment

| Implementation State | Readiness |
|---------------------|-----------|
| Current framework (no changes) | 70% |
| After Phase A (Foundation) | 75% |
| After Phase B (Checkpoints) | 85% |
| After Phase C (Batch Operations) | 92% |
| After Phase D (Full Execution) | 98% |

The "Funnel with Checkpoints" design ensures:
- **Human input is front-loaded** - all creative decisions made upfront
- **Parallelism where safe** - spec and task creation batched
- **Explicit coordination** - two alignment reviews catch drift early
- **Smart autonomy** - agent handles low-risk drift, escalates high-risk

---

## Appendix: Key File References

| Purpose | File Path |
|---------|-----------|
| Roadmap Schema | `profiles/default/schemas/roadmap.schema.json` |
| Spec Meta Schema | `profiles/default/schemas/spec-meta.schema.json` |
| Tasks Schema | `profiles/default/schemas/tasks.schema.json` |
| Findings Schema | `profiles/default/schemas/findings.schema.json` |
| Spec Research | `profiles/default/workflows/specification/research-spec.md` |
| Spec Writing | `profiles/default/workflows/specification/write-spec.md` |
| Task Creation | `profiles/default/workflows/implementation/create-tasks-list.md` |
| Task Implementation | `profiles/default/workflows/implementation/implement-tasks.md` |
| Orchestration | `profiles/default/commands/orchestrate-tasks/orchestrate-tasks.md` |
| Findings Review | `profiles/default/workflows/maintenance/review-findings.md` |
