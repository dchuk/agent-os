# Spec Initialization

## Core Responsibilities

1. **Get the description of the feature:** Receive it from the user or check the product roadmap
2. **Link to roadmap item:** Associate this spec with its roadmap item
3. **Initialize Spec Structure**: Create the spec folder with date prefix
4. **Create spec-meta.json**: Initialize metadata tracking for this spec
5. **Update roadmap.json**: Mark the roadmap item as specced and link to this spec
6. **Prepare for Requirements**: Set up structure for next phase

## Workflow

### Step 1: Get the description of the feature

IF you were given a description of the feature, then use that to initiate a new spec.

OTHERWISE follow these steps to get the description:

1. Read `agent-os/product/roadmap.json` to find the next planned (not yet specced) feature
2. Look for items where `status` is `"planned"` and all `dependencies` are `"completed"`
3. OUTPUT the following to user and WAIT for user's response:

```
Which feature would you like to initiate a new spec for?

- The roadmap shows "[FEATURE_TITLE]" (roadmap-XXX) is next. Go with that?
- Or provide a description of a different feature.
```

**If you have not yet received a description from the user, WAIT until user responds.**

### Step 2: Identify the Roadmap Item

Determine which roadmap item this spec implements:

1. If the user selected a roadmap item, use that ID
2. If the user provided a custom description, ask them:
   - "Should I add this as a new roadmap item, or does it correspond to an existing one?"
3. Store the `roadmapItemId` for use in spec-meta.json

### Step 3: Initialize Spec Structure

Determine a kebab-case spec name from the description, then create the spec folder:

```bash
# Get today's date in YYYY-MM-DD format
TODAY=$(date +%Y-%m-%d)

# Determine kebab-case spec name from description
SPEC_NAME="[kebab-case-name]"

# Create dated folder name
DATED_SPEC_NAME="${TODAY}-${SPEC_NAME}"

# Store this path for output
SPEC_PATH="agent-os/specs/$DATED_SPEC_NAME"

# Create folder structure
mkdir -p $SPEC_PATH/planning
mkdir -p $SPEC_PATH/planning/visuals
mkdir -p $SPEC_PATH/implementation
mkdir -p $SPEC_PATH/verification

echo "Created spec folder: $SPEC_PATH"
```

### Step 4: Create spec-meta.json

Create the metadata file at `$SPEC_PATH/spec-meta.json` following the schema at `agent-os/schemas/spec-meta.schema.json`.

The schema defines all required and optional fields. Key guidance:

- Set `specId` to the dated folder name (e.g., `2025-01-10-user-auth`)
- Set `roadmapItemId` to the linked roadmap item ID or null
- Set initial `status` to `"drafting"`
- Set `createdAt` to current ISO 8601 timestamp
- All other timestamp fields start as null
- All `files` tracking fields start as false/0
- `findingsGenerated` starts as empty array

### Step 5: Update roadmap.json

If this spec is linked to a roadmap item, update `agent-os/product/roadmap.json`:

1. Find the item with matching `id`
2. Update the following fields:
   - `status`: `"specced"`
   - `specPath`: `"agent-os/specs/[DATED_SPEC_NAME]"`
   - `speccedAt`: `"[CURRENT_ISO_TIMESTAMP]"`
3. Update `lastUpdated` at the root level

### Step 6: Output Confirmation

Return or output the following:

```
Spec folder initialized: `[spec-path]`

Structure created:
- spec-meta.json - Metadata and roadmap linkage
- planning/ - For requirements and specifications
- planning/visuals/ - For mockups and screenshots
- implementation/ - For implementation documentation
- verification/ - For verification reports

[If linked to roadmap]
✅ Linked to roadmap item: [ROADMAP_ITEM_ID] - [ROADMAP_ITEM_TITLE]
✅ Roadmap updated: status changed to "specced"

Ready for requirements research phase.
```

## Important Constraints

- Always use dated folder names (YYYY-MM-DD-spec-name)
- Always create spec-meta.json with roadmap linkage
- Always update roadmap.json when a roadmap item is being specced
- Pass the exact spec path back to the orchestrator
- Follow folder structure exactly
