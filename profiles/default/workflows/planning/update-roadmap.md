# Update Roadmap

Manage roadmap items: add new features, update status, defer items, or reorder priorities.

## Operations

### Add New Roadmap Item

When adding a new feature to the roadmap:

1. Read `agent-os/product/roadmap.json`
2. Find the highest existing ID number
3. Create new item with next ID (e.g., if highest is `roadmap-007`, use `roadmap-008`)
4. Add to items array
5. Update `lastUpdated`

```json
{
  "id": "roadmap-[NEXT_NUMBER]",
  "title": "[Feature Title]",
  "description": "[1-2 sentence description]",
  "status": "planned",
  "effort": "[XS|S|M|L|XL]",
  "priority": [NEXT_PRIORITY_NUMBER],
  "dependencies": ["[roadmap-ids if any]"],
  "specPath": null,
  "tags": ["[relevant-tags]"],
  "createdAt": "[CURRENT_ISO_TIMESTAMP]",
  "speccedAt": null,
  "startedAt": null,
  "completedAt": null,
  "deferredAt": null,
  "deferredReason": null
}
```

### Defer a Roadmap Item

When deferring a feature:

1. Find the item by ID
2. Update:
   - `status`: `"deferred"`
   - `deferredAt`: current ISO timestamp
   - `deferredReason`: reason provided by user
3. Update `lastUpdated`

### Reactivate a Deferred Item

When bringing back a deferred feature:

1. Find the item by ID
2. Update:
   - `status`: `"planned"`
   - `deferredAt`: `null`
   - `deferredReason`: `null`
3. Update `lastUpdated`

### Reprioritize Items

When changing priorities:

1. Read all items
2. Update `priority` values as specified
3. Ensure no duplicate priorities (shift others if needed)
4. Update `lastUpdated`

Note: Lower number = higher priority. Priority 1 is the most important.

### Update Dependencies

When changing what a feature depends on:

1. Find the item by ID
2. Update the `dependencies` array with roadmap item IDs
3. Validate all referenced IDs exist
4. Check for circular dependencies
5. Update `lastUpdated`

### View Roadmap Status

To display current roadmap status:

```
## Roadmap Status

**Product:** [productName]
**Last Updated:** [lastUpdated]

### Completed ([count])
- ✅ roadmap-001: [title] ([effort]) - Completed [date]
- ✅ roadmap-002: [title] ([effort]) - Completed [date]

### In Progress ([count])
- 🔄 roadmap-003: [title] ([effort]) - Started [date]
  - Spec: [specPath]

### Ready to Start ([count])
(Items where all dependencies are completed)
- ⏳ roadmap-004: [title] ([effort])
  - Dependencies: ✅ roadmap-001, ✅ roadmap-002

### Blocked ([count])
(Items with incomplete dependencies)
- 🚫 roadmap-006: [title] ([effort])
  - Waiting on: 🔄 roadmap-003

### Planned ([count])
- 📋 roadmap-005: [title] ([effort])

### Deferred ([count])
- ⏸️ roadmap-007: [title] - [deferredReason]
```

## Validation Rules

When modifying roadmap.json, always validate:

1. **Unique IDs**: No duplicate roadmap item IDs
2. **Valid Dependencies**: All referenced dependency IDs exist
3. **No Circular Dependencies**: Item cannot depend on itself or create loops
4. **Sequential Priorities**: No gaps (1, 2, 3... not 1, 3, 5)
5. **Status Consistency**: 
   - `specPath` should be set when status is `specced` or later
   - Timestamps should be set appropriately for status
6. **Schema Compliance**: All required fields present

## Integration Points

When roadmap changes occur, ensure consistency with:

1. **spec-meta.json**: If a roadmap item has a `specPath`, that spec's `roadmapItemId` should match
2. **tasks.json**: If spec has tasks, `roadmapItemId` should match
3. **AGENTS.md**: Consider noting major roadmap changes

## Example: Complete Feature Lifecycle

```
1. Feature added to roadmap
   roadmap.json: status="planned", specPath=null

2. User runs /shape-spec selecting this feature
   roadmap.json: status="specced", specPath="agent-os/specs/..."
   spec-meta.json: created with roadmapItemId

3. User runs /write-spec
   (roadmap unchanged, spec-meta updated)

4. User runs /create-tasks
   tasks.json: created with roadmapItemId
   spec-meta.json: status="tasked"

5. User runs /implement-tasks
   roadmap.json: status="in-progress", startedAt set
   tasks.json: task statuses update
   spec-meta.json: status="in-progress"

6. Implementation completes
   roadmap.json: status="completed", completedAt set
   tasks.json: status="completed"
   spec-meta.json: status="completed"
   findings.json: new findings added
```
