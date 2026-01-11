# Spec Writing

## Core Responsibilities

1. **Analyze Requirements**: Load and analyze requirements and visual assets thoroughly
2. **Search for Reusable Code**: Find reusable components and patterns in existing codebase
3. **Create Specification**: Write comprehensive specification document
4. **Update spec-meta.json**: Mark spec as specced

## Workflow

### Step 1: Analyze Requirements and Context

Read the following files:

```bash
# Read requirements
cat agent-os/specs/[this-spec]/planning/requirements.md

# Read spec metadata for roadmap linkage
cat agent-os/specs/[this-spec]/spec-meta.json

# Check for visual assets
ls -la agent-os/specs/[this-spec]/planning/visuals/ 2>/dev/null | grep -v "^total" | grep -v "^d"
```

Parse and analyze:
- User's feature description and goals
- Requirements gathered during shaping
- Visual mockups or screenshots (if present)
- Any constraints or out-of-scope items mentioned
- The linked roadmap item context

### Step 2: Search for Reusable Code

Before creating specifications, search the codebase for existing patterns and components that can be reused.

Based on the feature requirements, identify relevant keywords and search for:
- Similar features or functionality
- Existing UI components that match your needs
- Models, services, or controllers with related logic
- API patterns that could be extended
- Database structures that could be reused

Document your findings for use in the specification.

### Step 3: Create Core Specification

Write the main specification to `agent-os/specs/[this-spec]/spec.md`.

**DO NOT write actual code in the spec.md document.** Just describe the requirements clearly and concisely.

Keep it short and include only essential information for each section.

Follow this structure exactly:

```markdown
# Specification: [Feature Name]

## Metadata
- **Spec ID:** [spec-id]
- **Roadmap Item:** [roadmap-item-id] - [title]
- **Status:** Specced
- **Created:** [date]

## Goal
[1-2 sentences describing the core objective]

## User Stories
- As a [user type], I want to [action] so that [benefit]
- [Additional user stories as needed, max 5]

## Specific Requirements

### [Requirement Name]
- [Concise sub-bullet points clarifying this requirement]
- [Design or architectural decisions]
- [Technical approach to take]

[Repeat for each specific requirement, max 10]

## Visual Design
[If mockups provided]

### `planning/visuals/[filename]`
- [Key UI elements to implement]
- [Layout notes]
- [Interaction patterns]

[Repeat for each visual file]

## Existing Code to Leverage

### [Component/Pattern Name]
- **Location:** [file path]
- **What it does:** [brief description]
- **How to reuse:** [guidance]

[Repeat for relevant existing code, max 5]

## Out of Scope
- [Features explicitly excluded]
- [Future enhancements not for this spec]

[Max 10 items]
```

### Step 4: Update spec-meta.json

Update `agent-os/specs/[this-spec]/spec-meta.json`:

1. Set `status` to `"specced"`
2. Set `speccedAt` to current ISO timestamp
3. Set `files.hasSpec` to `true`

### Step 5: Verify Roadmap Link

Ensure `agent-os/product/roadmap.json` has the correct linkage:

1. Find the roadmap item matching `roadmapItemId`
2. Verify `specPath` points to this spec folder
3. Verify `status` is at least `"specced"`

If any discrepancies, update roadmap.json:
- Set `specPath` to `"agent-os/specs/[this-spec]"`
- Set `status` to `"specced"` (if currently `"planned"`)
- Set `speccedAt` to current ISO timestamp (if not set)
- Update `lastUpdated`

### Step 6: Output Completion

```
Specification complete!

✅ Created: `agent-os/specs/[this-spec]/spec.md`
✅ Updated: spec-meta.json (status: specced)
✅ Verified: roadmap.json linkage

**Spec Summary:**
- [X] requirements documented
- [Y] visuals referenced
- [Z] existing code patterns identified
- [N] out-of-scope items defined

Ready for task breakdown. Run /create-tasks to continue.
```

## Important Constraints

1. **Always search for reusable code** before specifying new components
2. **Reference visual assets** when available
3. **Do NOT write actual code** in the spec
4. **Keep each section short** with clear, scannable specifications
5. **Do NOT deviate from the template** - no additional sections
6. **Always update spec-meta.json** after creating spec
7. **Always verify roadmap linkage** is correct
