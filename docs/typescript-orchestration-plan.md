# TypeScript Orchestration System for Agent OS

**Date:** 2026-01-21
**Status:** Proposal
**Version:** 1.0.0

---

## Executive Summary

This plan outlines converting Agent OS from a pure markdown/YAML documentation system into a **TypeScript-based orchestration layer** that uses the [Claude Agent SDK](https://github.com/anthropics/claude-agent-sdk-typescript) to programmatically drive Claude Code. The key innovations are:

1. **TypeScript handles orchestration** - Batching, lifecycle management, and task execution happen in TypeScript, not Claude Code slash commands
2. **Fresh sessions per task group** - Implements the [Ralph Wiggum strategy](https://github.com/frankbria/ralph-claude-code) where each task group executes in a clean context window
3. **Prompt templates in TypeScript** - Commands like `/write-spec` become prompt templates stored in the TypeScript project and sent via the Agent SDK
4. **Skills/Agents as project files** - Claude Code reads skill/agent definitions from the target project's `.claude/` directory for behavioral guidance during execution

---

## Problem Statement

### Current Limitations

| Issue | Impact |
|-------|--------|
| **Context pollution** | Long sessions accumulate irrelevant context, degrading performance |
| **No programmatic batching** | User must manually run `/shape-spec`, `/write-spec` for each item |
| **Session isolation impossible** | Can't easily start fresh per task group |
| **Slash commands limited** | Commands run inside Claude Code's context, not orchestratable |
| **No parallel execution** | Can't spin up multiple Claude Code instances programmatically |

### Why TypeScript Orchestration Solves This

```
┌─────────────────────────────────────────────────────────────────────┐
│                     CURRENT ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   User ──▶ Claude Code ──▶ /slash-command ──▶ Markdown workflows    │
│              │                                                       │
│              └─── One long session, context grows unbounded          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     PROPOSED ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   User ──▶ TypeScript CLI ──▶ Orchestrator ──▶ Claude Agent SDK     │
│                                    │                                 │
│                                    ├─▶ Fresh Session: shape spec 1   │
│                                    ├─▶ Fresh Session: shape spec 2   │
│                                    ├─▶ Fresh Session: write spec 1   │
│                                    ├─▶ Fresh Session: write spec 2   │
│                                    └─▶ ... (parallel where safe)     │
│                                                                      │
│   Each session reads skills/agents from project directory            │
│   State persists in files (roadmap.json, tasks.json, specs/)         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Core Architecture

### System Components

```
agent-os/
├── src/                           # TypeScript orchestration layer
│   ├── index.ts                   # CLI entry point
│   ├── orchestrator/
│   │   ├── Orchestrator.ts        # Main orchestration engine
│   │   ├── SessionManager.ts      # Spawns/manages Claude sessions
│   │   ├── StateManager.ts        # Reads/writes JSON state files
│   │   └── BatchProcessor.ts      # Handles parallel/sequential batching
│   ├── lifecycle/
│   │   ├── PlanningPhase.ts       # Roadmap creation orchestration
│   │   ├── SpecificationPhase.ts  # Spec shaping/writing orchestration
│   │   ├── ImplementationPhase.ts # Task execution orchestration
│   │   └── AlignmentPhase.ts      # Cross-spec alignment checks
│   ├── prompts/                   # ★ PROMPT TEMPLATES (sent via SDK)
│   │   ├── PromptBuilder.ts       # Constructs prompts from templates
│   │   ├── PromptRegistry.ts      # Maps commands to prompt templates
│   │   └── templates/             # The actual prompt templates
│   │       ├── plan-product.md    # Roadmap creation prompt
│   │       ├── shape-spec.md      # Requirements gathering prompt
│   │       ├── write-spec.md      # Spec writing prompt
│   │       ├── create-tasks.md    # Task breakdown prompt
│   │       ├── implement-tasks.md # Implementation prompt
│   │       ├── align-specs.md     # Cross-spec alignment prompt
│   │       └── review-findings.md # Findings review prompt
│   ├── profiles/
│   │   ├── ProfileInstaller.ts    # Installs profiles into projects
│   │   └── ProfileLoader.ts       # Loads profile configurations
│   └── utils/
│       ├── FileSystem.ts          # File operations
│       ├── GitOperations.ts       # Git state tracking
│       └── Logger.ts              # Structured logging
├── profiles/                      # Profile definitions (installed to projects)
│   ├── default/
│   │   ├── agents/                # Agent behavior definitions
│   │   │   ├── implementer.md     # How to implement code
│   │   │   ├── spec-writer.md     # How to write specs
│   │   │   └── ...
│   │   ├── workflows/             # Workflow reference docs
│   │   ├── standards/             # Coding standards
│   │   └── schemas/               # JSON schemas for validation
│   └── rails-apps/
│       ├── agents/                # Rails-specific agents
│       └── standards/             # Rails coding standards
├── package.json
├── tsconfig.json
└── README.md

# When installed into a target project:
target-project/
├── .claude/
│   ├── agents/                    # ★ Claude Code reads these during execution
│   │   ├── implementer.md         # Behavioral guidance for implementation
│   │   ├── spec-writer.md         # Behavioral guidance for spec writing
│   │   └── ...
│   └── settings.json              # Claude Code configuration
├── agent-os/
│   ├── product/                   # State files
│   │   ├── roadmap.json
│   │   ├── mission.md
│   │   └── findings.json
│   ├── specs/                     # Spec directories
│   └── standards/                 # Coding standards (referenced by agents)
└── agent-os.config.json           # Orchestrator configuration
```

### Key Distinction: Prompt Templates vs Agent Files

| Component | Location | Purpose | Used By |
|-----------|----------|---------|---------|
| **Prompt Templates** | `src/prompts/templates/` | Commands sent to Claude via SDK | TypeScript Orchestrator |
| **Agent Files** | `.claude/agents/` in target project | Behavioral guidance during execution | Claude Code |
| **Standards** | `agent-os/standards/` in target project | Coding standards referenced by agents | Claude Code |
| **Workflows** | Referenced in prompt templates | Step-by-step procedures | Embedded in prompts |

### The Ralph Wiggum Pattern in TypeScript

The Ralph Wiggum strategy's core insight: **"Disk is state, Git is memory."**

Each Claude Code session:
1. Starts with a **fresh context window** (no prior conversation)
2. Reads current state from **files** (roadmap.json, tasks.json, specs/)
3. Receives a **focused prompt** for one specific task
4. Writes results back to **files**
5. Exits cleanly

The orchestrator manages session lifecycle:

```typescript
// Conceptual implementation
import { query } from '@anthropic-ai/claude-agent-sdk';

class SessionManager {
  async executeTask(task: Task, workingDir: string): Promise<TaskResult> {
    // Each task gets a FRESH session
    const prompt = this.buildPrompt(task);

    const session = query({
      prompt,
      options: {
        workingDirectory: workingDir,
        model: task.model || 'claude-sonnet-4-5-20250929',
        // Skills loaded from project directory automatically
        // Agents loaded from project directory automatically
        allowedTools: ['Read', 'Write', 'Edit', 'Bash', 'Glob', 'Grep'],
      }
    });

    const result = await this.consumeSession(session);

    // Session ends, context is discarded
    // Only file changes persist
    return result;
  }
}
```

---

## Detailed Design

### 1. Profile Installation

Converts existing bash installation into TypeScript with enhanced capabilities.

```typescript
// src/profiles/ProfileInstaller.ts

interface InstallOptions {
  profile: string;           // 'default' | 'rails-apps' | custom
  targetDir: string;         // Project directory
  claudeCodeSkills: boolean; // Install as Claude Code skills
  includeSchemas: boolean;   // Copy JSON schemas
}

class ProfileInstaller {
  async install(options: InstallOptions): Promise<void> {
    const profile = await this.loadProfile(options.profile);

    // Create agent-os directory structure
    await this.createDirectoryStructure(options.targetDir);

    // Install skills as Claude Code skill files
    if (options.claudeCodeSkills) {
      await this.installSkills(profile, options.targetDir);
    }

    // Copy schemas for validation
    if (options.includeSchemas) {
      await this.copySchemas(profile, options.targetDir);
    }

    // Initialize empty state files
    await this.initializeStateFiles(options.targetDir);
  }

  private async installSkills(profile: Profile, targetDir: string): Promise<void> {
    const skillsDir = path.join(targetDir, '.claude', 'skills');

    for (const skill of profile.skills) {
      // Skills are markdown files that Claude Code reads
      await fs.writeFile(
        path.join(skillsDir, `${skill.name}.md`),
        skill.content
      );
    }
  }
}
```

### 2. Prompt Templates in TypeScript

Prompt templates are stored in the TypeScript project and sent to Claude Code via the Agent SDK. They are NOT installed into target projects.

```typescript
// src/prompts/templates/shape-spec.md (stored as string or file in TS project)

const SHAPE_SPEC_TEMPLATE = `
# Shape Specification

You are a product requirements specialist. Your task is to gather detailed
requirements for the specified roadmap item through structured Q&A.

## Context Files to Read

1. \`agent-os/product/roadmap.json\` - Current roadmap
2. \`agent-os/product/mission.md\` - Product vision
3. \`agent-os/product/tech-stack.md\` - Technical decisions
4. \`agent-os/product/findings.json\` - Institutional knowledge

## Your Task

Shape roadmap item: {{roadmapItemId}}
- Title: {{item.title}}
- Description: {{item.description}}
- Dependencies: {{item.dependencies}}

## Process

1. Read the specified roadmap item from roadmap.json
2. Read any related specs (items this depends on)
3. Generate 5-10 clarifying questions organized by category
4. Collect answers through conversation
5. Write structured requirements to \`agent-os/specs/{{specPath}}/planning/requirements.md\`
6. Update spec-meta.json with status: "shaped"

## Output Format

Create a requirements.md with sections:
- Overview
- User Stories
- Technical Requirements
- Edge Cases & Error Handling
- Open Questions
`;
```

The orchestrator builds and sends the prompt:

```typescript
// src/prompts/PromptBuilder.ts

class PromptBuilder {
  private templates: Map<string, string>;

  constructor() {
    // Load templates from src/prompts/templates/
    this.templates = this.loadTemplates();
  }

  build(templateName: string, variables: Record<string, any>): string {
    const template = this.templates.get(templateName);
    if (!template) throw new Error(`Template ${templateName} not found`);

    // Replace {{variable}} placeholders
    return template.replace(/\{\{(\w+(?:\.\w+)*)\}\}/g, (_, path) => {
      return this.getNestedValue(variables, path) ?? '';
    });
  }
}

// Usage in orchestrator
const prompt = promptBuilder.build('shape-spec', {
  roadmapItemId: 'roadmap-001',
  item: roadmapItem,
  specPath: '2026-01-21-auth',
});

// Send via Claude Agent SDK
const session = query({ prompt, options: { workingDirectory: projectDir } });
```

### 3. Agent Files in Target Projects

Agent files are installed into target projects' `.claude/agents/` directory. These provide **behavioral guidance** that Claude Code reads during execution - they're NOT the commands themselves.

```markdown
<!-- Installed to: target-project/.claude/agents/implementer.md -->
---
name: implementer
description: Expert software engineer implementing tasks
---

# Implementer Agent

You are an expert software engineer. When implementing tasks:

## Core Principles

1. **Execute, don't plan** - Write actual code, not descriptions
2. **TDD when specified** - Write tests before implementation
3. **One task at a time** - Complete each before moving on
4. **Verify with tests** - Run tests after each change

## Standards to Follow

Read and apply standards from:
- \`agent-os/standards/global/\` - Universal standards
- \`agent-os/standards/backend/\` - Backend-specific (if applicable)
- \`agent-os/standards/frontend/\` - Frontend-specific (if applicable)

## Task Completion

A task is complete when:
- Code compiles without errors
- Tests pass (if applicable)
- tasks.json status updated to "completed"
```

The orchestrator's prompt can reference these agents:

```typescript
// The prompt template references the agent
const IMPLEMENT_TASKS_TEMPLATE = `
You are acting as the "implementer" agent defined in .claude/agents/implementer.md.
Read that file to understand your behavioral guidelines.

## Your Task

Implement task group "{{taskGroup.name}}" ({{taskGroup.id}}) for spec {{specId}}.

## Files to Read

1. .claude/agents/implementer.md - Your behavioral guidelines
2. agent-os/specs/{{specId}}/spec.md - The specification
3. agent-os/specs/{{specId}}/tasks.json - Task breakdown
4. agent-os/standards/ - Coding standards to follow

## Task Group Details

{{taskGroupJson}}

## Instructions

Follow the implementer agent guidelines and complete all tasks in this group.
`;
```

### 3. Lifecycle Orchestration

Each lifecycle phase has its own orchestration class:

```typescript
// src/lifecycle/SpecificationPhase.ts

class SpecificationPhase {
  constructor(
    private sessionManager: SessionManager,
    private stateManager: StateManager,
    private batchProcessor: BatchProcessor
  ) {}

  /**
   * Phase 1: Sequential shaping with human-in-the-loop
   */
  async shapeSpecs(itemIds: string[]): Promise<ShapingResult[]> {
    const results: ShapingResult[] = [];

    for (const itemId of itemIds) {
      // Each shaping session is fresh
      const result = await this.sessionManager.executeTask({
        type: 'shape-spec',
        itemId,
        interactive: true, // Allows Q&A with user
      });

      results.push(result);

      // State persisted to files after each item
      await this.stateManager.updateSpecStatus(itemId, 'shaped');
    }

    return results;
  }

  /**
   * Phase 2: Parallel spec writing (after shaping complete)
   */
  async writeSpecsParallel(itemIds: string[]): Promise<SpecResult[]> {
    // All shaped items can be written in parallel
    const tasks = itemIds.map(id => ({
      type: 'write-spec',
      itemId: id,
      interactive: false,
    }));

    // BatchProcessor spawns parallel Claude sessions
    return this.batchProcessor.executeParallel(tasks, {
      maxConcurrency: 4, // Configurable
      onProgress: (completed, total) => {
        console.log(`Writing specs: ${completed}/${total}`);
      }
    });
  }

  /**
   * Checkpoint: Cross-spec alignment review
   */
  async alignSpecs(itemIds: string[]): Promise<AlignmentReport> {
    // Single session reads ALL specs and checks for conflicts
    return this.sessionManager.executeTask({
      type: 'align-specs',
      itemIds,
      interactive: true, // User reviews and approves
    });
  }
}
```

### 4. Batch Processing with Parallelism

```typescript
// src/orchestrator/BatchProcessor.ts

interface BatchOptions {
  maxConcurrency: number;
  retryAttempts: number;
  onProgress?: (completed: number, total: number) => void;
  onError?: (task: Task, error: Error) => void;
}

class BatchProcessor {
  constructor(private sessionManager: SessionManager) {}

  async executeParallel<T>(
    tasks: Task[],
    options: BatchOptions
  ): Promise<T[]> {
    const results: T[] = [];
    const queue = [...tasks];
    const inFlight = new Map<string, Promise<T>>();

    while (queue.length > 0 || inFlight.size > 0) {
      // Fill up to maxConcurrency
      while (queue.length > 0 && inFlight.size < options.maxConcurrency) {
        const task = queue.shift()!;
        const promise = this.executeWithRetry(task, options.retryAttempts);
        inFlight.set(task.id, promise);
      }

      // Wait for any to complete
      const completed = await Promise.race(
        [...inFlight.entries()].map(async ([id, promise]) => {
          const result = await promise;
          return { id, result };
        })
      );

      results.push(completed.result);
      inFlight.delete(completed.id);
      options.onProgress?.(results.length, tasks.length);
    }

    return results;
  }

  async executeSequential<T>(tasks: Task[]): Promise<T[]> {
    const results: T[] = [];

    for (const task of tasks) {
      // Each task gets fresh context (Ralph Wiggum style)
      const result = await this.sessionManager.executeTask(task);
      results.push(result);
    }

    return results;
  }
}
```

### 5. Task Execution with Fresh Sessions

The implementation phase uses fresh sessions per task group:

```typescript
// src/lifecycle/ImplementationPhase.ts

class ImplementationPhase {
  /**
   * Execute all task groups for a spec, each in a fresh session
   */
  async executeSpec(specId: string): Promise<SpecExecutionResult> {
    const tasks = await this.stateManager.loadTasks(specId);
    const results: TaskGroupResult[] = [];

    // Sort task groups by dependencies
    const sorted = this.topologicalSort(tasks.taskGroups);

    for (const taskGroup of sorted) {
      // Skip if dependencies not complete
      if (!this.dependenciesSatisfied(taskGroup, results)) {
        results.push({
          id: taskGroup.id,
          status: 'blocked',
          reason: 'Dependencies not satisfied'
        });
        continue;
      }

      // FRESH SESSION for each task group (Ralph Wiggum)
      const prompt = this.buildImplementationPrompt(taskGroup, specId);

      const result = await this.sessionManager.executeTask({
        type: 'implement-task-group',
        prompt,
        workingDir: this.projectDir,
        // Context is ONLY what's in the prompt + files on disk
      });

      // Update state after each task group
      await this.stateManager.updateTaskGroupStatus(
        specId,
        taskGroup.id,
        result.status
      );

      // Capture findings
      if (result.findings?.length) {
        await this.stateManager.appendFindings(result.findings);
      }

      results.push(result);

      // Check for drift and decide if we need to stop
      if (result.driftDetected && result.driftSeverity === 'high') {
        console.log('High-severity drift detected. Pausing for user input.');
        const decision = await this.promptUserForDriftResolution(result);
        if (decision === 'abort') break;
      }
    }

    return { specId, taskGroupResults: results };
  }

  private buildImplementationPrompt(
    taskGroup: TaskGroup,
    specId: string
  ): string {
    // Load and populate the prompt template
    return this.promptBuilder.build('implement-tasks', {
      taskGroup,
      specId,
      taskGroupJson: JSON.stringify(taskGroup, null, 2),
    });
  }
}

// Example: src/prompts/templates/implement-tasks.md
const IMPLEMENT_TASKS_TEMPLATE = `
# Implementation Task

You are acting as the "implementer" agent. Read .claude/agents/implementer.md for behavioral guidelines.

## Your Task

Implement task group "{{taskGroup.name}}" ({{taskGroup.id}}) for spec {{specId}}.

## Context to Read

1. .claude/agents/implementer.md - Your behavioral guidelines
2. agent-os/specs/{{specId}}/spec.md - The specification
3. agent-os/specs/{{specId}}/tasks.json - Task breakdown
4. agent-os/product/tech-stack.md - Technical decisions
5. agent-os/product/findings.json - Patterns and gotchas
6. agent-os/standards/ - Coding standards to follow

## Task Group Details

{{taskGroupJson}}

## Instructions

1. Read the implementer agent guidelines
2. Read the spec and understand the requirements
3. Read the task group and its tasks/subtasks
4. Implement each task in order
5. Run tests after each significant change
6. Update tasks.json status after completing each task
7. Capture any findings (patterns, gotchas, decisions)
8. Report completion or blockers

## Completion

When ALL tasks in this group are complete:
1. Update tasks.json with status: "completed"
2. Write any findings to a temp file for collection
3. Provide a summary of what was implemented
`;`
```

### 6. State Management

State persists in files, enabling fresh sessions to pick up where previous sessions left off:

```typescript
// src/orchestrator/StateManager.ts

class StateManager {
  constructor(private projectDir: string) {}

  async loadRoadmap(): Promise<Roadmap> {
    const path = this.resolvePath('agent-os/product/roadmap.json');
    return JSON.parse(await fs.readFile(path, 'utf-8'));
  }

  async updateRoadmapItem(id: string, updates: Partial<RoadmapItem>): Promise<void> {
    const roadmap = await this.loadRoadmap();
    const item = roadmap.items.find(i => i.id === id);
    if (!item) throw new Error(`Roadmap item ${id} not found`);

    Object.assign(item, updates);

    await fs.writeFile(
      this.resolvePath('agent-os/product/roadmap.json'),
      JSON.stringify(roadmap, null, 2)
    );
  }

  async loadTasks(specId: string): Promise<TasksFile> {
    const path = this.resolvePath(`agent-os/specs/${specId}/tasks.json`);
    return JSON.parse(await fs.readFile(path, 'utf-8'));
  }

  async appendFindings(findings: Finding[]): Promise<void> {
    const path = this.resolvePath('agent-os/product/findings.json');
    const existing = JSON.parse(await fs.readFile(path, 'utf-8'));

    for (const finding of findings) {
      finding.id = this.generateFindingId(existing);
      existing.findings.push(finding);
    }

    existing.lastUpdated = new Date().toISOString();

    await fs.writeFile(path, JSON.stringify(existing, null, 2));
  }

  // Git operations for tracking changes
  async commitState(message: string): Promise<string> {
    const result = await exec('git add agent-os/ && git commit -m ' +
      JSON.stringify(message));
    return result.stdout.trim();
  }

  async getChangesSinceCommit(commitSha: string): Promise<string[]> {
    const result = await exec(`git diff --name-only ${commitSha} HEAD`);
    return result.stdout.trim().split('\n').filter(Boolean);
  }
}
```

### 7. CLI Interface

```typescript
// src/index.ts

import { Command } from 'commander';
import { Orchestrator } from './orchestrator/Orchestrator';

const program = new Command();

program
  .name('agent-os')
  .description('TypeScript orchestration for AI-driven development')
  .version('1.0.0');

// Profile management
program
  .command('install')
  .description('Install Agent OS into a project')
  .option('-p, --profile <name>', 'Profile to install', 'default')
  .option('-d, --dir <path>', 'Target directory', '.')
  .action(async (options) => {
    const installer = new ProfileInstaller();
    await installer.install({
      profile: options.profile,
      targetDir: options.dir,
      claudeCodeSkills: true,
      includeSchemas: true,
    });
    console.log('Agent OS installed successfully');
  });

// Planning phase
program
  .command('plan')
  .description('Create or update product roadmap')
  .action(async () => {
    const orchestrator = new Orchestrator();
    await orchestrator.runPlanningPhase();
  });

// Specification phase
program
  .command('spec')
  .description('Create specs for roadmap items')
  .option('--shape-only', 'Only run shaping phase')
  .option('--parallel', 'Write specs in parallel after shaping')
  .option('--items <ids...>', 'Specific items to spec')
  .action(async (options) => {
    const orchestrator = new Orchestrator();

    if (options.shapeOnly) {
      await orchestrator.shapeSpecs(options.items);
    } else if (options.parallel) {
      await orchestrator.runSpecificationPhaseParallel(options.items);
    } else {
      await orchestrator.runSpecificationPhase(options.items);
    }
  });

// Alignment checkpoints
program
  .command('align')
  .description('Run alignment review')
  .option('--specs', 'Align specs')
  .option('--tasks', 'Align tasks')
  .action(async (options) => {
    const orchestrator = new Orchestrator();

    if (options.specs) {
      await orchestrator.alignSpecs();
    } else if (options.tasks) {
      await orchestrator.alignTasks();
    }
  });

// Implementation phase
program
  .command('implement')
  .description('Execute implementation')
  .option('--spec <id>', 'Implement specific spec')
  .option('--all', 'Implement all ready specs in order')
  .option('--fresh-sessions', 'Use fresh session per task group (default: true)')
  .action(async (options) => {
    const orchestrator = new Orchestrator();

    if (options.spec) {
      await orchestrator.implementSpec(options.spec);
    } else if (options.all) {
      await orchestrator.implementAllSpecs();
    }
  });

// Full roadmap execution
program
  .command('execute')
  .description('Execute entire roadmap autonomously')
  .option('--spec-only', 'Stop after creating all specs')
  .option('--checkpoint-at <phase>', 'Pause at checkpoint')
  .action(async (options) => {
    const orchestrator = new Orchestrator();
    await orchestrator.executeRoadmap({
      specOnly: options.specOnly,
      checkpointAt: options.checkpointAt,
    });
  });

program.parse();
```

---

## Workflow Examples

### Example 1: Full Roadmap Execution

```bash
# User has a roadmap.json with 5 items

$ agent-os execute

[Planning] Validating roadmap...
[Planning] Found 5 items: auth, profiles, dashboard, notifications, settings

[Shaping] Starting sequential shaping with human-in-the-loop...
[Session 1/5] Shaping "auth"...
  > Q1: What authentication methods should be supported?
  < JWT with refresh tokens, OAuth for Google/GitHub
  > Q2: Should we support MFA?
  < Yes, TOTP-based
  ... (user answers questions)
[Session 1/5] Complete. Requirements written to agent-os/specs/2026-01-21-auth/

[Session 2/5] Shaping "profiles"...
  ... (continues for each item)

[Spec Writing] Starting parallel spec writing (4 concurrent)...
[Session 1] Writing auth spec... ✓
[Session 2] Writing profiles spec... ✓
[Session 3] Writing dashboard spec... ✓
[Session 4] Writing notifications spec... ✓
[Session 5] Writing settings spec... ✓

[Checkpoint 1] Running spec alignment review...
[Session] Comparing 5 specs for conflicts...
  ! Conflict: auth uses `userId`, profiles uses `user_id`
  ! Recommendation: Standardize on `userId`

  Approve changes? [Y/n]: y
  Applying changes... ✓

[Task Creation] Starting parallel task creation (4 concurrent)...
[Session 1-5] Creating task lists... ✓ (5/5)

[Checkpoint 2] Running task alignment review...
[Session] Validating cross-spec dependencies...
  ! Dependency: profiles.tg-02 needs auth.tg-03 complete first
  ! Adding cross-spec dependency link...

  Approve execution order?
  1. auth
  2. profiles
  3. dashboard (parallel)
  4. notifications (parallel)
  5. settings

  [Y/n]: y

[Execution] Starting implementation (fresh session per task group)...

[Spec: auth] Starting implementation...
  [Session] Task Group 1: Database schema... ✓
  [Session] Task Group 2: Auth service... ✓
  [Session] Task Group 3: API endpoints... ✓
  [Session] Task Group 4: Tests... ✓
  [Spec: auth] Complete ✓

[Spec: profiles] Starting implementation...
  [Session] Task Group 1: Database schema... ✓
  [Session] Task Group 2: Profile service... ✓
  ...

[Complete] All 5 specs implemented successfully
  Total sessions spawned: 23
  Findings captured: 7
  Time elapsed: 4h 32m
```

### Example 2: Resuming After Interruption

Because state is in files, the orchestrator can resume from any point:

```bash
# Previous run was interrupted during profiles implementation

$ agent-os execute

[Resuming] Detected existing state...
  Completed: auth (status: completed)
  In Progress: profiles (task group 2 of 4 complete)
  Pending: dashboard, notifications, settings

Resume from profiles task group 3? [Y/n]: y

[Spec: profiles] Resuming implementation...
  [Session] Task Group 3: API endpoints... ✓
  [Session] Task Group 4: Tests... ✓
  [Spec: profiles] Complete ✓

... (continues)
```

### Example 3: Parallel Spec Writing Only

```bash
# Just want to create all specs, not implement yet

$ agent-os spec --parallel

[Shaping] Starting sequential shaping...
... (user answers questions for each item)

[Spec Writing] Starting parallel spec writing...
[Session 1-5] Writing specs... ✓ (5/5)

[Complete] 5 specs created
  auth: agent-os/specs/2026-01-21-auth/
  profiles: agent-os/specs/2026-01-21-profiles/
  dashboard: agent-os/specs/2026-01-21-dashboard/
  notifications: agent-os/specs/2026-01-21-notifications/
  settings: agent-os/specs/2026-01-21-settings/
```

---

## Key Design Decisions

### 1. Why Fresh Sessions (Ralph Wiggum)?

| Benefit | Explanation |
|---------|-------------|
| **No context pollution** | Each task group starts clean, no accumulated confusion |
| **Predictable behavior** | Same prompt + same files = same result |
| **Parallelism** | Independent sessions can run concurrently |
| **Resumability** | Interrupted work can restart from files |
| **Cost efficiency** | Smaller context windows = lower token costs |

### 2. Why Prompt Templates in TypeScript + Agent Files in Project?

**Prompt Templates (in TypeScript):**
| Benefit | Explanation |
|---------|-------------|
| **Type-safe** | Template variables validated at compile time |
| **Testable** | Unit test prompt construction |
| **Versioned with orchestrator** | Templates evolve with orchestration logic |
| **Not exposed to users** | Implementation detail, not customization point |

**Agent Files (in target project's `.claude/`):**
| Benefit | Explanation |
|---------|-------------|
| **Customizable** | Users can tweak agent behavior per project |
| **Versionable** | Tracked in project git |
| **Profile-specific** | Different profiles install different agents |
| **Claude Code native** | Claude Code auto-discovers agents in `.claude/` |

### 3. Why TypeScript Orchestration (Not Bash)?

| Benefit | Explanation |
|---------|-------------|
| **Type safety** | Catch errors at compile time |
| **Async/await** | Natural parallel execution patterns |
| **NPM ecosystem** | Rich libraries for JSON, git, file ops |
| **SDK integration** | First-class Claude Agent SDK support |
| **Testability** | Unit test orchestration logic |

---

## Implementation Phases

### Phase 1: Foundation

**Goal:** Basic TypeScript project with profile installation

1. Initialize TypeScript project with proper config
2. Implement `ProfileInstaller` - copies agents/standards/schemas to target project
3. Implement `StateManager` - read/write JSON state files
4. Create prompt template system from existing commands
5. Basic CLI with `install` command

**Deliverables:**
- `agent-os install` works
- Agents appear in target project's `.claude/agents/`
- Standards appear in target project's `agent-os/standards/`
- State files initialized in `agent-os/product/`
- Prompt templates loaded from `src/prompts/templates/`

### Phase 2: Session Management

**Goal:** Spawn and manage Claude Code sessions via SDK

1. Implement `SessionManager` with Claude Agent SDK integration
2. Implement `PromptBuilder` - constructs prompts from templates with variable interpolation
3. Create fresh session pattern (one session per task)
4. Add session result parsing and error handling
5. Implement basic retry logic

**Deliverables:**
- Can spawn Claude Code session with custom prompt from template
- Session runs against target project directory (where agents are installed)
- Claude Code reads `.claude/agents/` for behavioral guidance
- Results captured and parsed

### Phase 3: Lifecycle Phases (Week 5-6)

**Goal:** Orchestrate planning, specification, implementation phases

1. Implement `PlanningPhase` - roadmap creation
2. Implement `SpecificationPhase` - shaping and spec writing
3. Implement `ImplementationPhase` - task execution with fresh sessions
4. Add CLI commands for each phase
5. Implement progress tracking and reporting

**Deliverables:**
- `agent-os plan` creates roadmap
- `agent-os spec` shapes and writes specs
- `agent-os implement` executes tasks

### Phase 4: Batch Processing (Week 7-8)

**Goal:** Parallel execution and batching

1. Implement `BatchProcessor` with configurable concurrency
2. Add parallel spec writing
3. Add parallel task creation
4. Implement dependency-aware execution ordering
5. Add progress reporting for parallel operations

**Deliverables:**
- `agent-os spec --parallel` writes specs concurrently
- Multiple Claude sessions run simultaneously
- Dependencies respected in execution order

### Phase 5: Alignment & Checkpoints (Week 9-10)

**Goal:** Cross-spec coordination and drift detection

1. Implement `AlignmentPhase` - spec and task alignment
2. Add checkpoint system with user approval
3. Implement drift detection during execution
4. Add risk-based autonomy (low risk = auto-resolve)
5. Add cascade change checking

**Deliverables:**
- `agent-os align --specs` reviews all specs
- Checkpoints pause for user input
- Drift detected and classified by severity

### Phase 6: Full Execution & Polish (Week 11-12)

**Goal:** End-to-end autonomous execution

1. Implement `execute` command for full roadmap
2. Add resume capability from any state
3. Implement comprehensive error handling
4. Add detailed logging and reporting
5. Documentation and examples

**Deliverables:**
- `agent-os execute` runs full workflow
- Interrupted runs resume cleanly
- Comprehensive documentation

---

## Configuration

### agent-os.config.json

```json
{
  "profile": "default",
  "orchestration": {
    "maxConcurrency": 4,
    "sessionTimeout": 300000,
    "retryAttempts": 3,
    "freshSessionsPerTaskGroup": true
  },
  "models": {
    "shaping": "claude-sonnet-4-5-20250929",
    "specWriting": "claude-sonnet-4-5-20250929",
    "taskCreation": "claude-sonnet-4-5-20250929",
    "implementation": "claude-sonnet-4-5-20250929",
    "alignment": "claude-opus-4-5-20251101"
  },
  "checkpoints": {
    "afterSpecAlignment": true,
    "afterTaskAlignment": true,
    "onHighSeverityDrift": true
  },
  "logging": {
    "level": "info",
    "file": "agent-os.log"
  }
}
```

---

## Comparison with Current System

| Aspect | Current (Markdown) | Proposed (TypeScript) |
|--------|-------------------|----------------------|
| **Batching** | Manual slash commands | Automatic batch processing |
| **Parallelism** | None (single session) | Configurable concurrency |
| **Context** | Grows unbounded | Fresh per task group |
| **Resumability** | Manual restart | Automatic from state files |
| **Cross-spec coordination** | None | Alignment checkpoints |
| **Orchestration** | User drives | TypeScript drives |
| **Commands** | Slash commands in Claude Code | Prompt templates sent via SDK |
| **Agent behavior** | Embedded in commands | Files in `.claude/agents/` |

---

## Dependencies

### NPM Packages

```json
{
  "dependencies": {
    "@anthropic-ai/claude-agent-sdk": "^0.2.14",
    "commander": "^12.0.0",
    "ajv": "^8.12.0",
    "glob": "^10.3.0",
    "fs-extra": "^11.2.0",
    "chalk": "^5.3.0",
    "ora": "^8.0.0"
  },
  "devDependencies": {
    "typescript": "^5.3.0",
    "@types/node": "^20.0.0",
    "vitest": "^1.2.0",
    "tsx": "^4.7.0"
  }
}
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| **SDK API changes** | Pin SDK version, monitor changelog |
| **Rate limiting** | Configurable concurrency, exponential backoff |
| **Session failures** | Retry logic, state persistence enables resume |
| **Context too large** | Keep prompts focused, rely on file reading |
| **Skill drift** | Version skills in git, validate at install time |

---

## Success Metrics

1. **Context efficiency**: 80% reduction in context window usage vs. single-session approach
2. **Parallelism**: 4x speedup for spec writing and task creation phases
3. **Resumability**: 100% of interrupted runs can resume from state files
4. **Reliability**: <5% session failure rate with retry logic
5. **User satisfaction**: Full roadmap execution without manual intervention

---

## Next Steps

1. **Review this plan** - Gather feedback on architecture decisions
2. **Set up TypeScript project** - Initialize with proper config
3. **Implement Phase 1** - Profile installation
4. **Prototype SDK integration** - Verify Claude Agent SDK works as expected
5. **Iterate** - Refine based on real-world usage

---

## References

- [Claude Agent SDK - TypeScript](https://github.com/anthropics/claude-agent-sdk-typescript)
- [Ralph Wiggum Technique](https://github.com/frankbria/ralph-claude-code)
- [Agent OS v3.0.0 Assessment](./assessment-roadmap-spec-workflow.md)
- [11 Tips for AI Coding with Ralph Wiggum](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum)
- [Claude Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)

---

## Appendix A: Prompt Template Format

Prompt templates are stored in `src/prompts/templates/` and support variable interpolation:

```markdown
<!-- src/prompts/templates/write-spec.md -->

# Write Specification

You are acting as the "spec-writer" agent. Read .claude/agents/spec-writer.md for behavioral guidelines.

## Your Task

Write a complete specification for roadmap item: {{roadmapItemId}}
- Title: {{item.title}}
- Description: {{item.description}}

## Context to Read

1. .claude/agents/spec-writer.md - Your behavioral guidelines
2. agent-os/specs/{{specPath}}/planning/requirements.md - Shaped requirements
3. agent-os/product/mission.md - Product vision
4. agent-os/product/tech-stack.md - Technical decisions
5. agent-os/product/findings.json - Relevant patterns

## Output

Write the specification to: agent-os/specs/{{specPath}}/spec.md

The spec should include:
- Overview and goals
- Detailed requirements
- Technical approach
- API contracts (if applicable)
- Data models (if applicable)
- Edge cases and error handling
- Testing strategy

After writing, update spec-meta.json with status: "specced"
```

## Appendix A.2: Agent File Format

Agent files are installed to target project's `.claude/agents/` and provide behavioral guidance:

```markdown
<!-- Installed to: target-project/.claude/agents/spec-writer.md -->
---
name: spec-writer
description: Technical writer creating detailed specifications
---

# Spec Writer Agent

You write clear, comprehensive technical specifications.

## Core Principles

1. **Be specific** - Avoid ambiguity, provide concrete examples
2. **Think about edge cases** - Document error conditions
3. **Consider dependencies** - Note what other specs this relates to
4. **Stay in scope** - Don't expand beyond the shaped requirements

## Standards to Follow

Read and apply standards from:
- `agent-os/standards/global/` - Universal standards

## Writing Style

- Use clear, concise language
- Include code examples where helpful
- Structure with clear headings
- Add diagrams (mermaid) for complex flows
```

---

## Appendix B: Target Project File Locations

```
target-project/
├── agent-os/                      # State files (read/written by Claude)
│   ├── product/
│   │   ├── mission.md             # Product vision
│   │   ├── roadmap.json           # Roadmap items with statuses
│   │   ├── tech-stack.md          # Technical decisions
│   │   └── findings.json          # Institutional knowledge
│   ├── specs/
│   │   ├── 2026-01-21-auth/
│   │   │   ├── spec-meta.json     # Spec metadata and status
│   │   │   ├── spec.md            # Full specification
│   │   │   ├── tasks.json         # Task breakdown
│   │   │   └── planning/
│   │   │       └── requirements.md
│   │   └── 2026-01-21-profiles/
│   │       └── ...
│   └── standards/                 # Coding standards (from profile)
│       ├── global/
│       ├── backend/
│       └── frontend/
├── .claude/                       # Claude Code configuration
│   ├── agents/                    # Agent behavioral guidance
│   │   ├── implementer.md
│   │   ├── spec-writer.md
│   │   ├── product-planner.md
│   │   └── ...
│   └── settings.json              # Claude Code settings
└── agent-os.config.json           # Orchestrator configuration
```

## Appendix B.2: TypeScript Project File Locations

```
agent-os/                          # The orchestrator (this project)
├── src/
│   ├── prompts/
│   │   └── templates/             # ★ Prompt templates (sent via SDK)
│   │       ├── plan-product.md
│   │       ├── shape-spec.md
│   │       ├── write-spec.md
│   │       ├── create-tasks.md
│   │       ├── implement-tasks.md
│   │       ├── align-specs.md
│   │       └── review-findings.md
│   ├── orchestrator/
│   ├── lifecycle/
│   └── ...
├── profiles/                      # Profile definitions (installed to projects)
│   ├── default/
│   │   ├── agents/                # → Installed to .claude/agents/
│   │   ├── standards/             # → Installed to agent-os/standards/
│   │   └── schemas/               # → Installed to agent-os/schemas/
│   └── rails-apps/
└── ...
```

---

## Appendix C: Message Flow Diagram

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   User      │     │  TypeScript  │     │  Claude Agent   │
│   (CLI)     │     │ Orchestrator │     │      SDK        │
└─────────────┘     └──────────────┘     └─────────────────┘
       │                   │                      │
       │ agent-os execute  │                      │
       │──────────────────▶│                      │
       │                   │                      │
       │                   │ Read roadmap.json    │
       │                   │─────────────────────▶│
       │                   │                      │
       │                   │ For each item:       │
       │                   │                      │
       │                   │ ┌────────────────┐   │
       │                   │ │ Fresh Session  │   │
       │                   │ │  shape-spec    │   │
       │                   │ └────────────────┘   │
       │◀──────────────────│ Q&A with user       │
       │ Answer questions  │                      │
       │──────────────────▶│                      │
       │                   │──────────────────────▶ query()
       │                   │                      │
       │                   │◀─────────────────────│ Stream results
       │                   │                      │
       │                   │ Write requirements.md│
       │                   │                      │
       │                   │ ┌────────────────┐   │
       │                   │ │ Fresh Session  │   │
       │                   │ │  write-spec    │   │
       │                   │ └────────────────┘   │
       │                   │──────────────────────▶ query()
       │                   │                      │
       │                   │◀─────────────────────│
       │                   │                      │
       │                   │ Write spec.md        │
       │                   │                      │
       │                   │ ... (parallel for    │
       │                   │      remaining specs)│
       │                   │                      │
       │◀──────────────────│ Checkpoint: align   │
       │ Approve alignment │                      │
       │──────────────────▶│                      │
       │                   │                      │
       │                   │ ... (implementation) │
       │                   │                      │
       │◀──────────────────│ Complete            │
       │                   │                      │
```
