# Gather Product Info

Collect comprehensive product information from the user to initialize product planning.

## Workflow

### Step 1: Check for Existing Product Files

```bash
# Check if product folder already exists
if [ -d "agent-os/product" ]; then
    echo "Product documentation already exists."
    ls -la agent-os/product/
fi
```

If `roadmap.json` exists, ask user if they want to:
- Add to existing roadmap
- Start fresh (backup existing)

### Step 2: Gather Required Information

Collect from user:

**Required:**
- **Product Name**: Name of the product
- **Product Idea**: Core concept and purpose
- **Key Features**: Minimum 3 features with descriptions
- **Target Users**: At least 1 user segment with use cases

**Optional:**
- **Tech Stack**: Confirmation or customization of tech stack
- **Effort Estimates**: For each feature if known

If any required information is missing, prompt:

```
Please provide the following to create your product plan:

1. **Product Name**: What is your product called?

2. **Main Idea**: What problem does it solve? (2-3 sentences)

3. **Key Features** (minimum 3):
   - Feature 1: [name] - [brief description]
   - Feature 2: [name] - [brief description]
   - Feature 3: [name] - [brief description]

4. **Target Users**: Who will use this product and why?

5. **Tech Stack** (optional): Will this use your standard tech stack, or something different?
```

### Step 3: Create Product Directory

```bash
mkdir -p agent-os/product
mkdir -p agent-os/specs
mkdir -p agent-os/schemas
```

### Step 4: Initialize roadmap.json

Create `agent-os/product/roadmap.json` with gathered features:

```json
{
  "schemaVersion": "1.0.0",
  "productName": "[PRODUCT_NAME]",
  "lastUpdated": "[CURRENT_ISO_TIMESTAMP]",
  "items": []
}
```

For each feature provided, add an item:

```json
{
  "id": "roadmap-001",
  "title": "[FEATURE_NAME]",
  "description": "[FEATURE_DESCRIPTION]",
  "status": "planned",
  "effort": "[ESTIMATE or 'M' as default]",
  "priority": [1, 2, 3...],
  "dependencies": [],
  "specPath": null,
  "tags": [],
  "createdAt": "[CURRENT_ISO_TIMESTAMP]",
  "speccedAt": null,
  "startedAt": null,
  "completedAt": null,
  "deferredAt": null,
  "deferredReason": null
}
```

### Step 5: Determine Feature Order

Ask user to confirm or adjust the priority order:

```
Based on what you've shared, here's a suggested feature order:

1. [Feature A] - [reason: foundational/enables others]
2. [Feature B] - [reason: depends on A]
3. [Feature C] - [reason: depends on A]
4. [Feature D] - [reason: depends on B and C]

Does this order make sense? Feel free to adjust priorities or add dependencies.
```

Update `priority` and `dependencies` based on user feedback.

### Step 6: Copy Schema Files

Ensure schema files are available in the project:

```bash
mkdir -p agent-os/schemas
# Copy schema files to agent-os/schemas/
```

Create or copy:
- `roadmap.schema.json`
- `tasks.schema.json`
- `findings.schema.json`
- `spec-meta.schema.json`

### Step 7: Initialize findings.json

Create empty findings file:

```json
{
  "schemaVersion": "1.0.0",
  "lastUpdated": "[CURRENT_ISO_TIMESTAMP]",
  "lastReviewedAt": null,
  "findings": []
}
```

### Step 8: Output Summary

```
Product initialization complete!

**Product:** [PRODUCT_NAME]

**Roadmap Created:** agent-os/product/roadmap.json
- [X] features planned
- Priority order established
- Dependencies mapped

**Next Steps:**
1. Run /plan-product to create mission.md and tech-stack.md
2. Run /shape-spec to start working on the first feature

**Schemas installed:** agent-os/schemas/
- roadmap.schema.json
- tasks.schema.json
- findings.schema.json
- spec-meta.schema.json
```

## Validation

Before completing, validate:

1. All features have unique titles
2. Priority numbers are sequential (1, 2, 3...)
3. Dependencies reference valid roadmap IDs
4. No circular dependencies
5. Product name is set
6. At least 3 features are defined
