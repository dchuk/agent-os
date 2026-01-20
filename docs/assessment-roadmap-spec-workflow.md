# Assessment: Roadmap-Driven Spec Workflow with Continuous Alignment

**Date:** 2026-01-20
**Prepared for:** Product workflow optimization analysis
**Agent OS Version:** 3.0.0

---

## Executive Summary

This assessment evaluates how well Agent OS can support a workflow where:
1. A product roadmap is created upfront
2. Specs are created for ALL roadmap items before implementation begins
3. An AI agent iterates through each spec's tasks sequentially
4. As work progresses, future tasks are "aligned" to stay on track
5. As specs are completed, subsequent spec creation factors in prior work for consistency

**Overall Assessment: 70% Ready** - The framework has strong foundations but lacks explicit mechanisms for cross-spec alignment and batch spec processing.

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

The main gaps are **cross-spec awareness** and **automated batch processing**. These can be addressed with targeted modifications:

1. **Quick wins** (cross-spec context, findings consultation) add ~20% more consistency
2. **Batch commands** add ~30% efficiency gain
3. **Alignment system** adds ~40% drift prevention
4. **Autonomous processing** enables fully hands-off execution

With Priority 1-2 changes, the framework would be **85% ready**.
With all priorities implemented, it would be **95%+ ready** for the envisioned workflow.

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
