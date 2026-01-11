<img width="1280" height="640" alt="agent-os-og" src="https://github.com/user-attachments/assets/f70671a2-66e8-4c80-8998-d4318af55d10" />

## Your system for spec-driven agentic development.

[Agent OS](https://buildermethods.com/agent-os) transforms AI coding agents from confused interns into productive developers. With structured workflows that capture your standards, your stack, and the unique details of your codebase, Agent OS gives your agents the specs they need to ship quality code on the first try—not the fifth.

Use it with:

- Claude Code, Cursor, or any other AI coding tool.
- New products or established codebases.
- Big features, small fixes, or anything in between.
- Any language or framework.

---

## Installation

### 1. Base Installation

Install Agent OS to your home directory:

```bash
curl -sSL https://raw.githubusercontent.com/buildermethods/agent-os/main/scripts/base-install.sh | bash
```

This creates `~/agent-os/` with:
- Configuration in `config.yml`
- Profiles in `profiles/`
- Installation scripts in `scripts/`

### 2. Project Installation

Navigate to your project and install Agent OS:

```bash
cd /path/to/your/project
~/agent-os/scripts/project-install.sh
```

Options:
```bash
# Dry run - see what would be installed
~/agent-os/scripts/project-install.sh --dry-run

# With specific options
~/agent-os/scripts/project-install.sh --claude-code-commands true --use-claude-code-subagents true

# See all options
~/agent-os/scripts/project-install.sh --help
```

### 3. Update an Existing Project

```bash
cd /path/to/your/project
~/agent-os/scripts/project-update.sh
```

---

## What's New in v3.0.0

Version 3.0.0 introduces structured JSON schemas, bidirectional linking, and a findings system for capturing institutional knowledge.

### Breaking Changes

- `roadmap.md` replaced with `roadmap.json`
- `tasks.md` replaced with `tasks.json`
- New `spec-meta.json` required in each spec folder
- New `findings.json` in product folder

### JSON Schemas for Core Data

All primary data files now use JSON with defined schemas:

| File | Location | Purpose |
|------|----------|---------|
| `roadmap.json` | `agent-os/product/` | Product feature roadmap with status tracking |
| `tasks.json` | `agent-os/specs/[spec]/` | Task breakdown for each spec |
| `findings.json` | `agent-os/product/` | Institutional knowledge captured during implementation |
| `spec-meta.json` | `agent-os/specs/[spec]/` | Spec metadata and roadmap linkage |

### Bidirectional Linking

Specs and roadmap items are now explicitly linked:

```
roadmap.json                          spec-meta.json
┌─────────────────────┐              ┌─────────────────────┐
│ id: "roadmap-003"   │◄────────────►│ roadmapItemId:      │
│ specPath: "agent-os │              │   "roadmap-003"     │
│   /specs/2025-01-10 │              │ specId: "2025-01-10 │
│   -project-org"     │              │   -project-org"     │
└─────────────────────┘              └─────────────────────┘
```

### Findings System

Agents now capture institutional knowledge during implementation:

- Build configuration gotchas
- Error patterns and solutions
- Established code patterns
- Testing strategies
- Architecture decisions

Findings are:
- Automatically captured post-implementation
- Deduplicated and merged when similar
- Reviewed periodically via `/review-findings`
- Synced to AGENTS.md for agent context

---

## File Structure

```
agent-os/
├── product/
│   ├── mission.md           # Product mission
│   ├── roadmap.json         # JSON roadmap with status tracking
│   ├── findings.json        # Captured learnings
│   └── tech-stack.md        # Tech stack
├── specs/
│   └── [YYYY-MM-DD-spec-name]/
│       ├── spec-meta.json   # Spec metadata and roadmap link
│       ├── spec.md          # Specification document
│       ├── tasks.json       # JSON task breakdown
│       ├── planning/
│       │   ├── requirements.md
│       │   └── visuals/
│       ├── implementation/
│       └── verification/
├── schemas/                  # JSON Schema definitions
│   ├── roadmap.schema.json
│   ├── tasks.schema.json
│   ├── findings.schema.json
│   └── spec-meta.schema.json
└── standards/               # Your coding standards
```

---

## Schema Reference

### roadmap.json

```json
{
  "schemaVersion": "1.0.0",
  "productName": "MyApp",
  "lastUpdated": "2025-01-11T14:30:00Z",
  "items": [
    {
      "id": "roadmap-001",
      "title": "User Authentication",
      "description": "Email/password auth with session management",
      "status": "completed",
      "effort": "M",
      "priority": 1,
      "dependencies": [],
      "specPath": "agent-os/specs/2025-01-05-user-auth",
      "tags": ["backend", "security"],
      "createdAt": "2025-01-02T10:00:00Z",
      "completedAt": "2025-01-08T16:30:00Z"
    }
  ]
}
```

**Status values:** `planned` → `specced` → `in-progress` → `completed` | `deferred`

**Effort scale:** `XS` (1 day), `S` (2-3 days), `M` (1 week), `L` (2 weeks), `XL` (3+ weeks)

### tasks.json

```json
{
  "schemaVersion": "1.0.0",
  "specId": "2025-01-10-project-org",
  "specTitle": "Project Organization",
  "roadmapItemId": "roadmap-003",
  "status": "in-progress",
  "summary": {
    "totalTaskGroups": 4,
    "completedTaskGroups": 2,
    "totalTasks": 12,
    "completedTasks": 7
  },
  "taskGroups": [
    {
      "id": "tg-001",
      "name": "Database Layer",
      "layer": "database",
      "dependencies": [],
      "status": "completed",
      "tasks": [...]
    }
  ]
}
```

**Layer values:** `database`, `api`, `frontend`, `testing`, `infrastructure`, `integration`, `other`

### findings.json

```json
{
  "schemaVersion": "1.0.0",
  "lastUpdated": "2025-01-11T14:00:00Z",
  "lastReviewedAt": null,
  "findings": [
    {
      "id": "finding-001",
      "category": "code-pattern",
      "title": "Form validation uses Zod schemas",
      "description": "The project uses Zod schemas in src/schemas/...",
      "context": "Any new form or API endpoint needing validation",
      "recommendation": "Create schema in src/schemas/[feature].schema.ts",
      "confidence": "high",
      "status": "active"
    }
  ]
}
```

**Categories:** `build-config`, `error-pattern`, `code-pattern`, `dependency`, `performance`, `testing`, `architecture`, `tooling`, `security`, `other`

**Confidence:** `low`, `medium`, `high`

### spec-meta.json

```json
{
  "schemaVersion": "1.0.0",
  "specId": "2025-01-10-project-org",
  "title": "Project Organization",
  "roadmapItemId": "roadmap-003",
  "status": "in-progress",
  "createdAt": "2025-01-10T15:00:00Z",
  "shapedAt": "2025-01-10T15:45:00Z",
  "speccedAt": "2025-01-10T16:30:00Z",
  "taskedAt": "2025-01-10T17:00:00Z",
  "implementationStartedAt": "2025-01-11T09:00:00Z",
  "completedAt": null,
  "findingsGenerated": ["finding-005"]
}
```

**Status values:** `drafting` → `shaped` → `specced` → `tasked` → `in-progress` → `completed` | `abandoned`

---

## Commands

| Command | Description |
|---------|-------------|
| `/plan-product` | Create product mission, roadmap, and tech stack |
| `/shape-spec` | Shape requirements for a feature |
| `/write-spec` | Write the specification document |
| `/create-tasks` | Break spec into tasks.json |
| `/implement-tasks` | Implement all tasks |
| `/orchestrate-tasks` | Advanced multi-agent task orchestration |
| `/review-findings` | Review and maintain findings database |

---

## Migration from v2.x

If you have existing markdown roadmaps and task files:

1. **Roadmap**: Manually convert `roadmap.md` to `roadmap.json` format
2. **Tasks**: Existing specs can continue with markdown tasks; new specs will use JSON
3. **Findings**: Start fresh - `findings.json` is initialized automatically

The installation scripts will:
- Install JSON schemas to `agent-os/schemas/`
- Initialize empty `findings.json` if it doesn't exist
- Not overwrite existing product files

---

## Documentation & Support

- Full documentation: [buildermethods.com/agent-os](https://buildermethods.com/agent-os)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
- Subscribe for updates: [buildermethods.com/agent-os](https://buildermethods.com/agent-os)

---

## Created by Brian Casel @ Builder Methods

Created by Brian Casel, the creator of [Builder Methods](https://buildermethods.com), where Brian helps professional software developers and teams build with AI.

Get Brian's free resources on building with AI:
- [Builder Briefing newsletter](https://buildermethods.com)
- [YouTube](https://youtube.com/@briancasel)

Join [Builder Methods Pro](https://buildermethods.com/pro) for official support and connect with our community of AI-first builders.
