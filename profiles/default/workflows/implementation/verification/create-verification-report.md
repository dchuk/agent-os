# Create Verification Report

Create the final verification report after all tasks have been implemented.

## Workflow

### Step 1: Verify All Tasks Complete

Read `agent-os/specs/[this-spec]/tasks.json` and verify:

1. Root `status` is `"completed"`
2. All task groups have `status: "completed"`
3. All tasks have `status: "completed"` or `status: "skipped"`
4. `summary.completedTaskGroups` equals `summary.totalTaskGroups`

If any tasks are incomplete, list them and stop - do not create verification report.

### Step 2: Verify Metadata Consistency

Read `agent-os/specs/[this-spec]/spec-meta.json` and verify:

1. `status` is `"completed"` or `"in-progress"`
2. `completedAt` is set (or will be set after this verification)
3. `roadmapItemId` matches the one in tasks.json

Read `agent-os/product/roadmap.json` and verify:

1. The linked roadmap item has `status: "completed"` or `status: "in-progress"`
2. `specPath` correctly points to this spec folder

### Step 3: Run Test Suite

Run the entire test suite for the application:

```bash
# Run all tests (adjust command for your test framework)
npm test
# or
yarn test
# or
pytest
# etc.
```

Record:
- Total tests run
- Tests passing
- Tests failing
- Any errors

**DO NOT attempt to fix failing tests.** Just document them.

### Step 4: Review Findings Generated

Read `agent-os/product/findings.json` and find any findings where `sourceSpec` matches this spec.

List these findings in the verification report.

### Step 5: Create Verification Report

Create `agent-os/specs/[this-spec]/verification/final-verification.md`:

```markdown
# Verification Report: [Spec Title]

**Spec:** `[spec-id]`
**Roadmap Item:** `[roadmap-item-id]` - [roadmap-item-title]
**Date:** [Current Date]
**Status:** ✅ Passed | ⚠️ Passed with Issues | ❌ Failed

---

## Executive Summary

[Brief 2-3 sentence overview of the verification results and overall implementation quality]

---

## 1. Task Completion

**Status:** ✅ All Complete | ⚠️ Issues Found

### Summary
- Task Groups: [completed]/[total]
- Tasks: [completed]/[total]
- Subtasks: [completed]/[total]

### Task Groups
| ID | Name | Status | Completed At |
|----|------|--------|--------------|
| tg-001 | [Name] | ✅ | [timestamp] |
| tg-002 | [Name] | ✅ | [timestamp] |

### Skipped Tasks
[List any tasks with status "skipped" and why, or "None"]

---

## 2. Test Results

**Status:** ✅ All Passing | ⚠️ Some Failures | ❌ Critical Failures

### Summary
- **Total Tests:** [count]
- **Passing:** [count]
- **Failing:** [count]
- **Errors:** [count]

### Failed Tests
[List failing tests with brief description, or "None - all tests passing"]

### Notes
[Any context about test failures - known issues, unrelated to this spec, etc.]

---

## 3. Roadmap & Metadata

**Status:** ✅ Updated | ⚠️ Issues Found

- Roadmap item `[id]` status: [status]
- Spec-meta.json status: [status]
- Linkage verified: ✅ | ❌

---

## 4. Findings Captured

**Findings from this spec:** [count]

[For each finding:]
### [finding-id]: [title]
- **Category:** [category]
- **Confidence:** [confidence]
- **Summary:** [brief description]

[Or "No new findings captured during this implementation"]

---

## 5. Implementation Notes

[Any notable decisions, deviations from spec, or context for future reference]

---

## Conclusion

[Overall assessment: Implementation complete and verified / Needs attention / etc.]
```

### Step 6: Update Final Status

If verification passed (all tasks complete, tests passing or failures documented):

Update `agent-os/specs/[this-spec]/spec-meta.json`:
1. Set `status` to `"completed"`
2. Set `completedAt` to current ISO timestamp (if not already set)

Update `agent-os/product/roadmap.json`:
1. Find the linked roadmap item
2. Set `status` to `"completed"` (if not already)
3. Set `completedAt` to current ISO timestamp (if not already set)
4. Update `lastUpdated`

### Step 7: Update AGENTS.md with Findings

If any new findings were captured during this implementation:

1. Read current AGENTS.md
2. Find or create the "## Agent Findings" section
3. Regenerate the findings list from `findings.json` (active findings only)
4. Group by category
5. Include title, confidence, and recommendation for each

See the review-findings workflow for the exact AGENTS.md format.
