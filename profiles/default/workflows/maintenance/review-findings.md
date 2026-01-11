# Review Findings

Review all findings and decide what to do with each one: keep active, archive, merge duplicates, or update.

## Purpose

Over time, findings accumulate and some may become:
- Obsolete (the codebase has changed)
- Duplicated (same pattern discovered multiple times)
- Superseded (a better approach was found)
- Low confidence and never confirmed

This command reviews all findings and cleans them up.

## Workflow

### Step 1: Load Findings

Read `agent-os/product/findings.json` and get all findings.

If the file doesn't exist or has no findings, output:
```
No findings to review. Findings are captured during implementation.
Run /implement-tasks to generate findings.
```

### Step 2: Analyze Each Finding

For each finding with `status: "active"`, evaluate:

1. **Still Valid?**
   - Check if `relatedFiles` still exist
   - Check if the pattern/issue still applies to the current codebase
   - If no longer valid → mark for archival

2. **Duplicates?**
   - Compare against other active findings
   - If substantially similar → mark for merge
   - Keep the one with higher confidence or more detail

3. **Confidence Level Appropriate?**
   - `confirmedCount` of 1 with `confidence: "high"` might need downgrade
   - `confirmedCount` > 3 with `confidence: "low"` might need upgrade

4. **Actionable?**
   - Does the `recommendation` still make sense?
   - Is it specific enough to be useful?

### Step 3: Present Review Summary

Output a summary for user confirmation:

```
## Findings Review Summary

**Total Active Findings:** [COUNT]
**Last Reviewed:** [DATE or "Never"]

### Recommended Actions:

**Archive (no longer valid):**
- finding-003: "[title]" - [reason]
- finding-007: "[title]" - [reason]

**Merge (duplicates):**
- finding-002 + finding-005: "[common topic]"
  - Keep: finding-002 (higher confidence)
  - Archive: finding-005

**Update Confidence:**
- finding-001: low → medium (confirmed 4 times)
- finding-008: high → medium (only confirmed once)

**Keep As-Is:**
- finding-004: "[title]" ✓
- finding-006: "[title]" ✓

Proceed with these changes? (y/n)
```

### Step 4: Apply Changes (on confirmation)

For each approved action:

**Archiving:**
```json
{
  "status": "archived",
  "archivedAt": "[CURRENT_ISO_TIMESTAMP]",
  "archivedReason": "[reason from review]"
}
```

**Merging (keep one, archive other):**
1. Update the kept finding:
   - Merge any unique `relatedFiles`
   - Update `confirmedCount` to sum of both
   - Update `lastConfirmedAt` to most recent
   - Potentially update `description` to be more comprehensive
2. Archive the other:
   - Set `status` to `"superseded"`
   - Set `supersededBy` to the kept finding's ID
   - Set `archivedAt` and `archivedReason`

**Confidence Updates:**
- Simply update the `confidence` field

### Step 5: Update AGENTS.md

After applying changes, regenerate the findings section in AGENTS.md:

```markdown
## Agent Findings

<!-- Auto-generated from findings.json - Last updated: [TIMESTAMP] -->
<!-- Run /review-findings to update -->

### Build & Configuration
- **[title]** ([confidence] confidence, confirmed [N] times)
  - [recommendation]

### Code Patterns
- **[title]** ([confidence] confidence, confirmed [N] times)
  - [recommendation]

### Error Patterns
- **[title]** ([confidence] confidence, confirmed [N] times)
  - [recommendation]

[Continue for each category with active findings]
```

### Step 6: Update Metadata

Update `findings.json`:
- Set `lastReviewedAt` to current ISO timestamp
- Update `lastUpdated`

### Step 7: Output Completion

```
## Review Complete

- Archived: [N] findings
- Merged: [N] finding pairs
- Confidence updated: [N] findings
- Active findings remaining: [N]

AGENTS.md has been updated with current findings.

Next review recommended: [DATE ~30 days from now]
```

## Review Triggers

Consider running this command:
- After completing a major feature (several specs)
- Monthly, as part of codebase maintenance
- When findings.json grows large (>20 active findings)
- Before starting a new major development phase
