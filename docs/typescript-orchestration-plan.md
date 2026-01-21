# TypeScript Orchestration System for WavePool

**Date:** 2026-01-21
**Status:** Proposal
**Version:** 1.2.0

---

## Executive Summary

This plan outlines converting WavePool from a pure markdown/YAML documentation system into a **TypeScript-based orchestration layer** that uses the [Claude Agent SDK](https://github.com/anthropics/claude-agent-sdk-typescript) to programmatically drive Claude Code. The key innovations are:

1. **TypeScript handles orchestration** - Batching, lifecycle management, and task execution happen in TypeScript, not Claude Code slash commands
2. **Fresh sessions per task group** - Implements the [Ralph Wiggum strategy](https://github.com/frankbria/ralph-claude-code) where each task group executes in a clean context window
3. **Prompt templates in TypeScript** - Commands like `/write-spec` become prompt templates stored in the TypeScript project and sent via the Agent SDK
4. **Skills/Agents as project files** - Claude Code reads skill/agent definitions from the target project's `.claude/` directory for behavioral guidance during execution
5. **Flexible interaction modes** - Questions can be delivered one-by-one (CLI) or batched as JSON (web/app wizards), with per-phase autonomy settings
6. **Decision logging** - All decisions (user or AI-made) are logged with artifact references for auditability

---

## Dual-Target Architecture: SDK + CLI

WavePool is designed as a **layered system** that supports two primary consumption patterns:

1. **Embeddable SDK** - A programmatic TypeScript library for integration into Electron apps, web applications, VS Code extensions, and other host environments
2. **Executable CLI** - A command-line interface built on top of the SDK for terminal-based workflows

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CONSUMPTION LAYERS                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌────────────┐  │
│   │  CLI App    │   │ Electron    │   │   Web App   │   │  VS Code   │  │
│   │  (Terminal) │   │    App      │   │  (Browser)  │   │ Extension  │  │
│   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘   └──────┬─────┘  │
│          │                 │                 │                 │         │
│          ▼                 ▼                 ▼                 ▼         │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                     CLI Layer (Optional)                         │   │
│   │    commander.js • terminal UI • progress bars • stdin/stdout     │   │
│   └─────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                      @wavepool/sdk (Core)                        │   │
│   │   Orchestrator • SessionManager • StateManager • BatchProcessor  │   │
│   │   PromptBuilder • LifecyclePhases • EventEmitter                 │   │
│   └─────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    Adapters (Pluggable)                          │   │
│   │   FileSystemAdapter • GitAdapter • ClaudeAdapter • UIAdapter     │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Why This Architecture?

| Goal | Solution |
|------|----------|
| **Reusability** | Core SDK can be embedded in any TypeScript/JavaScript environment |
| **Testability** | SDK functions can be unit tested without CLI dependencies |
| **Flexibility** | Different UIs (terminal, Electron, web) can wrap the same SDK |
| **Portability** | Adapters abstract platform differences (Node.js vs browser) |
| **Extensibility** | Host applications can provide custom adapters for storage, git, etc. |

### SDK vs CLI Responsibilities

| Component | SDK Responsibility | CLI Responsibility |
|-----------|-------------------|-------------------|
| **Orchestration** | Core logic, state machine, batching | None (uses SDK) |
| **Session Management** | Spawning, lifecycle, result parsing | None (uses SDK) |
| **User Interaction** | Emits events, accepts callbacks | Terminal prompts, progress bars |
| **File System** | Abstract `FileSystemAdapter` interface | Node.js `fs` implementation |
| **Progress Reporting** | Emits `progress`, `error`, `complete` events | Renders spinners, bars |
| **Configuration** | Loads and validates config | CLI flags override config |
| **Profile Management** | Profile loading and validation | Installation commands |

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

### Package Structure (Monorepo)

The project is organized as a monorepo with separate packages for SDK and CLI:

```
wavepool/
├── packages/
│   ├── sdk/                          # @wavepool/sdk - Core library
│   │   ├── src/
│   │   │   ├── index.ts              # Public API exports
│   │   │   ├── WavePool.ts            # Main entry point class
│   │   │   ├── orchestrator/
│   │   │   │   ├── Orchestrator.ts   # Main orchestration engine
│   │   │   │   ├── SessionManager.ts # Spawns/manages Claude sessions
│   │   │   │   ├── StateManager.ts   # Reads/writes state (via adapter)
│   │   │   │   └── BatchProcessor.ts # Parallel/sequential batching
│   │   │   ├── lifecycle/
│   │   │   │   ├── PlanningPhase.ts
│   │   │   │   ├── SpecificationPhase.ts
│   │   │   │   ├── ImplementationPhase.ts
│   │   │   │   └── AlignmentPhase.ts
│   │   │   ├── prompts/
│   │   │   │   ├── PromptBuilder.ts
│   │   │   │   ├── PromptRegistry.ts
│   │   │   │   └── templates/        # Bundled prompt templates
│   │   │   ├── adapters/             # ★ Pluggable adapters
│   │   │   │   ├── interfaces.ts     # Adapter interfaces
│   │   │   │   ├── NodeFileSystemAdapter.ts
│   │   │   │   ├── NodeGitAdapter.ts
│   │   │   │   └── DefaultClaudeAdapter.ts
│   │   │   ├── events/               # ★ Event system
│   │   │   │   ├── EventEmitter.ts
│   │   │   │   └── types.ts
│   │   │   └── types/
│   │   │       ├── config.ts
│   │   │       ├── roadmap.ts
│   │   │       ├── spec.ts
│   │   │       └── task.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── cli/                          # @wavepool/cli - Command-line interface
│       ├── src/
│       │   ├── index.ts              # CLI entry point
│       │   ├── commands/
│       │   │   ├── install.ts
│       │   │   ├── plan.ts
│       │   │   ├── spec.ts
│       │   │   ├── implement.ts
│       │   │   └── execute.ts
│       │   ├── ui/                   # Terminal UI components
│       │   │   ├── ProgressBar.ts
│       │   │   ├── Spinner.ts
│       │   │   ├── Prompts.ts        # Interactive prompts
│       │   │   └── Table.ts
│       │   └── adapters/
│       │       └── TerminalUIAdapter.ts
│       ├── package.json              # Depends on @wavepool/sdk
│       └── tsconfig.json
│
├── profiles/                         # Profile definitions (shared)
│   ├── default/
│   └── rails-apps/
├── package.json                      # Workspace root
├── turbo.json                        # Turborepo config
└── README.md
```

### System Components (Legacy Reference)

```
wavepool/
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
├── wavepool/
│   ├── product/                   # State files
│   │   ├── roadmap.json
│   │   ├── mission.md
│   │   ├── findings.json
│   │   └── decisions_log.json     # Decision audit trail
│   ├── specs/                     # Spec directories
│   └── standards/                 # Coding standards (referenced by agents)
└── wavepool.config.json           # Orchestrator configuration
```

### Key Distinction: Prompt Templates vs Agent Files

| Component | Location | Purpose | Used By |
|-----------|----------|---------|---------|
| **Prompt Templates** | `src/prompts/templates/` | Commands sent to Claude via SDK | TypeScript Orchestrator |
| **Agent Files** | `.claude/agents/` in target project | Behavioral guidance during execution | Claude Code |
| **Standards** | `wavepool/standards/` in target project | Coding standards referenced by agents | Claude Code |
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

## SDK Design

### Main Entry Point: WavePool Class

The SDK exposes a single primary entry point that orchestrates all functionality:

```typescript
// packages/sdk/src/WavePool.ts

import { EventEmitter } from './events/EventEmitter';
import { Orchestrator } from './orchestrator/Orchestrator';
import type { WavePoolConfig, Adapters, WavePoolEvents } from './types';

/**
 * Main entry point for the WavePool SDK.
 *
 * @example
 * // Basic usage
 * const wavePool = new WavePool({
 *   projectDir: '/path/to/project',
 *   profile: 'default',
 * });
 *
 * await wavePool.execute();
 *
 * @example
 * // With custom adapters (for Electron/Web)
 * const wavePool = new WavePool({
 *   projectDir: '/path/to/project',
 *   adapters: {
 *     fileSystem: new ElectronFileSystemAdapter(),
 *     git: new IsomorphicGitAdapter(),
 *     ui: new ElectronUIAdapter(mainWindow),
 *   }
 * });
 */
export class WavePool extends EventEmitter<WavePoolEvents> {
  private orchestrator: Orchestrator;
  private config: WavePoolConfig;

  constructor(config: WavePoolConfig) {
    super();
    this.config = this.resolveConfig(config);
    this.orchestrator = new Orchestrator(this.config, this);
  }

  // ============ LIFECYCLE METHODS ============

  /**
   * Execute the entire roadmap from start to finish.
   * Emits events throughout for progress tracking.
   */
  async execute(options?: ExecuteOptions): Promise<ExecutionResult> {
    this.emit('execute:start', { options });
    try {
      const result = await this.orchestrator.executeRoadmap(options);
      this.emit('execute:complete', { result });
      return result;
    } catch (error) {
      this.emit('execute:error', { error });
      throw error;
    }
  }

  /**
   * Run only the planning phase (create/update roadmap).
   */
  async plan(): Promise<PlanResult> {
    return this.orchestrator.runPlanningPhase();
  }

  /**
   * Run the specification phase for given items.
   */
  async spec(options?: SpecOptions): Promise<SpecResult[]> {
    if (options?.parallel) {
      return this.orchestrator.runSpecificationPhaseParallel(options.items);
    }
    return this.orchestrator.runSpecificationPhase(options?.items);
  }

  /**
   * Run the implementation phase for a specific spec or all ready specs.
   */
  async implement(options?: ImplementOptions): Promise<ImplementResult> {
    if (options?.specId) {
      return this.orchestrator.implementSpec(options.specId);
    }
    return this.orchestrator.implementAllSpecs();
  }

  /**
   * Run alignment checks on specs or tasks.
   */
  async align(target: 'specs' | 'tasks'): Promise<AlignmentReport> {
    return target === 'specs'
      ? this.orchestrator.alignSpecs()
      : this.orchestrator.alignTasks();
  }

  // ============ PROFILE MANAGEMENT ============

  /**
   * Install a profile into the target project.
   */
  async installProfile(profile?: string): Promise<void> {
    const profileName = profile || this.config.profile || 'default';
    await this.orchestrator.installProfile(profileName);
    this.emit('profile:installed', { profile: profileName });
  }

  // ============ STATE ACCESS ============

  /**
   * Get the current roadmap state.
   */
  async getRoadmap(): Promise<Roadmap> {
    return this.orchestrator.stateManager.loadRoadmap();
  }

  /**
   * Get specs with optional filtering.
   */
  async getSpecs(filter?: SpecFilter): Promise<SpecMeta[]> {
    return this.orchestrator.stateManager.loadSpecs(filter);
  }

  /**
   * Get findings from the knowledge base.
   */
  async getFindings(filter?: FindingsFilter): Promise<Finding[]> {
    return this.orchestrator.stateManager.loadFindings(filter);
  }

  // ============ CANCELLATION ============

  /**
   * Cancel any running operation.
   */
  cancel(): void {
    this.orchestrator.cancel();
    this.emit('cancelled', {});
  }
}
```

### Event System

The SDK uses a typed event emitter for all progress and status updates, enabling host applications to build reactive UIs:

```typescript
// packages/sdk/src/events/types.ts

export interface WavePoolEvents {
  // Lifecycle events
  'execute:start': { options?: ExecuteOptions };
  'execute:complete': { result: ExecutionResult };
  'execute:error': { error: Error };
  'cancelled': {};

  // Phase events
  'phase:start': { phase: Phase; itemCount: number };
  'phase:complete': { phase: Phase; results: any[] };

  // Session events (for fresh session tracking)
  'session:start': { sessionId: string; task: TaskInfo };
  'session:progress': { sessionId: string; message: string };
  'session:complete': { sessionId: string; result: SessionResult };
  'session:error': { sessionId: string; error: Error };

  // Batch processing events
  'batch:start': { total: number; concurrent: number };
  'batch:progress': { completed: number; total: number; current?: string };
  'batch:complete': { results: any[] };

  // User interaction events
  'interaction:required': {
    type: 'question' | 'approval' | 'choice';
    prompt: string;
    options?: string[];
    resolve: (answer: string) => void;
    reject: (reason: string) => void;
  };

  // Alignment events
  'alignment:conflict': { conflict: ConflictInfo; severity: Severity };
  'alignment:resolved': { conflict: ConflictInfo; resolution: string };

  // Drift detection
  'drift:detected': { drift: DriftInfo; severity: Severity };
  'drift:resolved': { drift: DriftInfo; resolution: string };

  // Profile events
  'profile:installed': { profile: string };

  // Decision logging events
  'decision:logged': { decision: Decision };
  'decision:user-answered': { decision: Decision };
  'decision:ai-decided': { decision: Decision };

  // Batch question events (for wizard-style UIs)
  'questions:batch': {
    phase: Phase;
    questions: Question[];
    resolve: (answers: Answer[]) => void;
    reject: (reason: string) => void;
  };
}

// Usage example in host application:
wavePool.on('session:start', ({ sessionId, task }) => {
  ui.showSpinner(`Starting: ${task.name}`);
});

wavePool.on('batch:progress', ({ completed, total }) => {
  ui.updateProgressBar(completed / total);
});

wavePool.on('interaction:required', async ({ type, prompt, options, resolve }) => {
  const answer = await ui.showDialog(type, prompt, options);
  resolve(answer);
});
```

### Adapter Interfaces

Adapters allow the SDK to work in different environments by abstracting platform-specific operations:

```typescript
// packages/sdk/src/adapters/interfaces.ts

/**
 * File system operations abstraction.
 * Implement for Node.js, Electron, browser (with virtual FS), etc.
 */
export interface FileSystemAdapter {
  readFile(path: string): Promise<string>;
  writeFile(path: string, content: string): Promise<void>;
  exists(path: string): Promise<boolean>;
  mkdir(path: string, options?: { recursive?: boolean }): Promise<void>;
  readdir(path: string): Promise<string[]>;
  stat(path: string): Promise<FileStat>;
  glob(pattern: string, options?: GlobOptions): Promise<string[]>;
  watch?(path: string, callback: (event: WatchEvent) => void): () => void;
}

/**
 * Git operations abstraction.
 * Implement using isomorphic-git for browser, simple-git for Node.js, etc.
 */
export interface GitAdapter {
  status(): Promise<GitStatus>;
  add(files: string[]): Promise<void>;
  commit(message: string): Promise<string>;
  log(options?: LogOptions): Promise<GitCommit[]>;
  diff(from?: string, to?: string): Promise<string>;
  getCurrentBranch(): Promise<string>;
}

/**
 * Claude interaction abstraction.
 * Default uses Claude Agent SDK, but can be mocked for testing.
 */
export interface ClaudeAdapter {
  query(options: QueryOptions): AsyncIterable<QueryEvent>;
  cancel(sessionId: string): Promise<void>;
}

/**
 * User interaction abstraction.
 * Enables different UI paradigms (terminal, GUI, headless).
 */
export interface UIAdapter {
  /**
   * Ask the user a question and get a response.
   * For CLI: terminal prompt
   * For Electron: dialog box
   * For headless: auto-respond or throw
   */
  prompt(options: PromptOptions): Promise<string>;

  /**
   * Ask user to select from choices.
   */
  select(options: SelectOptions): Promise<string>;

  /**
   * Ask for approval (yes/no).
   */
  confirm(message: string): Promise<boolean>;

  /**
   * Display progress information.
   * For CLI: spinner/progress bar
   * For GUI: progress dialog
   */
  showProgress(options: ProgressOptions): ProgressHandle;

  /**
   * Display an informational message.
   */
  info(message: string): void;

  /**
   * Display a warning.
   */
  warn(message: string): void;

  /**
   * Display an error.
   */
  error(message: string): void;
}

/**
 * Configuration for the SDK.
 */
export interface WavePoolConfig {
  // Required
  projectDir: string;

  // Optional - defaults provided
  profile?: string;
  configPath?: string;  // Path to wavepool.config.json

  // Orchestration settings
  orchestration?: {
    maxConcurrency?: number;
    sessionTimeout?: number;
    retryAttempts?: number;
    freshSessionsPerTaskGroup?: boolean;
  };

  // Model configuration
  models?: {
    shaping?: string;
    specWriting?: string;
    taskCreation?: string;
    implementation?: string;
    alignment?: string;
  };

  /**
   * Interaction mode configuration.
   * Controls how questions are delivered to the user.
   */
  interaction?: {
    /**
     * How to deliver questions to the user:
     * - 'sequential': One question at a time (better for CLI)
     * - 'batch': All questions at once as JSON array (better for web/app wizards)
     */
    questionDeliveryMode: 'sequential' | 'batch';
  };

  /**
   * Per-phase autonomy settings.
   * Controls whether the AI should ask the user or decide autonomously.
   */
  autonomy?: {
    /**
     * Planning phase: roadmap creation questions
     */
    planning?: AutonomyMode;
    /**
     * Shaping phase: requirements gathering Q&A
     */
    shaping?: AutonomyMode;
    /**
     * Spec writing phase: technical decisions
     */
    specWriting?: AutonomyMode;
    /**
     * Task creation phase: implementation approach
     */
    taskCreation?: AutonomyMode;
    /**
     * Alignment review phases: conflict resolution
     */
    alignment?: AutonomyMode;
    /**
     * Implementation phase: runtime decisions
     */
    implementation?: AutonomyMode;
  };

  // Custom adapters (optional - defaults used if not provided)
  adapters?: Partial<Adapters>;
}

/**
 * Autonomy mode for each phase.
 * - 'ask': Always stop and ask the user
 * - 'autonomous': AI decides on its own and logs the decision
 * - 'autonomous-low-risk': AI decides for low-risk items, asks for high-risk
 */
export type AutonomyMode = 'ask' | 'autonomous' | 'autonomous-low-risk';

export interface Adapters {
  fileSystem: FileSystemAdapter;
  git: GitAdapter;
  claude: ClaudeAdapter;
  ui: UIAdapter;
}
```

### Interaction Modes

WavePool supports two question delivery modes to accommodate different UI paradigms:

#### Sequential Mode (CLI-Friendly)

Questions are delivered one at a time, ideal for terminal-based workflows:

```typescript
// Sequential mode - questions come one by one
const wavePool = new WavePool({
  projectDir: '/path/to/project',
  interaction: {
    questionDeliveryMode: 'sequential',
  },
});

// Each question triggers a separate event
wavePool.on('interaction:required', async ({ type, prompt, resolve }) => {
  const answer = await terminalPrompt(prompt);
  resolve(answer);
});
```

#### Batch Mode (Wizard-Friendly)

All questions for a phase are collected and delivered at once as a JSON array, ideal for web/app wizard UIs:

```typescript
// Batch mode - questions come as a collection
const wavePool = new WavePool({
  projectDir: '/path/to/project',
  interaction: {
    questionDeliveryMode: 'batch',
  },
});

// All questions for a phase arrive together
wavePool.on('questions:batch', async ({ phase, questions, resolve }) => {
  // questions is an array like:
  // [
  //   { id: 'q1', prompt: 'What auth method?', type: 'choice', options: [...] },
  //   { id: 'q2', prompt: 'Support MFA?', type: 'boolean' },
  //   { id: 'q3', prompt: 'Session timeout?', type: 'text', default: '30m' },
  // ]

  // Display all questions in a wizard UI, collect answers
  const answers = await showWizardDialog(phase, questions);

  // answers is an array like:
  // [
  //   { questionId: 'q1', answer: 'JWT with refresh tokens' },
  //   { questionId: 'q2', answer: true },
  //   { questionId: 'q3', answer: '1h' },
  // ]
  resolve(answers);
});
```

#### Question and Answer Types

```typescript
// packages/sdk/src/types/interaction.ts

export interface Question {
  id: string;
  prompt: string;
  type: 'text' | 'choice' | 'multi-choice' | 'boolean' | 'number';
  options?: string[];        // For choice/multi-choice
  default?: any;             // Default value
  required?: boolean;        // Whether answer is required
  category?: string;         // Grouping hint for UI
  context?: string;          // Additional context/help text
  relatedArtifact?: {        // What this question relates to
    type: 'roadmap-item' | 'spec' | 'task' | 'finding';
    id: string;
    path?: string;
  };
}

export interface Answer {
  questionId: string;
  answer: any;
  answeredBy: 'user' | 'ai';
  confidence?: number;       // AI confidence (0-1) when AI answers
  reasoning?: string;        // AI reasoning when AI answers
}
```

### Per-Phase Autonomy

Control whether the AI should ask the user or decide autonomously for each workflow phase:

```typescript
const wavePool = new WavePool({
  projectDir: '/path/to/project',
  autonomy: {
    // User answers all requirements questions
    shaping: 'ask',

    // User answers spec writing questions
    specWriting: 'ask',

    // AI decides on task breakdown autonomously
    taskCreation: 'autonomous',

    // AI handles alignment reviews autonomously
    alignment: 'autonomous',

    // AI decides low-risk implementation questions, asks for high-risk
    implementation: 'autonomous-low-risk',
  },
});
```

| Mode | Behavior |
|------|----------|
| `'ask'` | Always stop and wait for user input |
| `'autonomous'` | AI decides and logs the decision for later review |
| `'autonomous-low-risk'` | AI decides for low-severity items, asks for high-severity |

### Decision Logging

All decisions—whether made by the user or AI—are logged to `wavepool/product/decisions_log.json` for auditability and review.

#### Decision Log Structure

```typescript
// packages/sdk/src/types/decision.ts

export interface Decision {
  id: string;                           // Unique decision ID
  timestamp: string;                    // ISO timestamp
  phase: Phase;                         // Which workflow phase

  // The question that prompted this decision
  question: {
    id: string;
    prompt: string;
    options?: string[];
  };

  // The answer/decision made
  answer: {
    value: any;
    answeredBy: 'user' | 'ai';
    confidence?: number;                // AI confidence (0-1)
    reasoning?: string;                 // AI's reasoning if autonomous
  };

  // What artifact this decision relates to
  relatedArtifact: {
    type: 'roadmap-item' | 'spec' | 'task' | 'task-group' | 'finding' | 'alignment';
    id: string;
    title?: string;
    path?: string;                      // File path if applicable
  };

  // Impact tracking
  impact?: {
    filesAffected?: string[];           // Files this decision influenced
    dependentDecisions?: string[];      // Other decisions that depend on this
  };

  // Review status
  reviewed?: boolean;
  reviewedAt?: string;
  reviewedBy?: string;
  reviewNotes?: string;
}

export interface DecisionsLog {
  version: string;
  projectId: string;
  lastUpdated: string;
  decisions: Decision[];

  // Summary statistics
  stats: {
    totalDecisions: number;
    userDecisions: number;
    aiDecisions: number;
    pendingReview: number;
    byPhase: Record<Phase, number>;
  };
}
```

#### Example decisions_log.json

```json
{
  "version": "1.0.0",
  "projectId": "my-app",
  "lastUpdated": "2026-01-21T14:30:00Z",
  "decisions": [
    {
      "id": "dec-001",
      "timestamp": "2026-01-21T10:15:00Z",
      "phase": "shaping",
      "question": {
        "id": "auth-method",
        "prompt": "What authentication methods should be supported?",
        "options": ["Session-based", "JWT", "OAuth only", "JWT + OAuth"]
      },
      "answer": {
        "value": "JWT + OAuth",
        "answeredBy": "user"
      },
      "relatedArtifact": {
        "type": "spec",
        "id": "2026-01-21-auth",
        "title": "User Authentication",
        "path": "wavepool/specs/2026-01-21-auth/spec.md"
      },
      "reviewed": false
    },
    {
      "id": "dec-002",
      "timestamp": "2026-01-21T12:30:00Z",
      "phase": "alignment",
      "question": {
        "id": "naming-conflict",
        "prompt": "Specs use inconsistent naming: 'userId' vs 'user_id'. Which should be standard?"
      },
      "answer": {
        "value": "userId",
        "answeredBy": "ai",
        "confidence": 0.92,
        "reasoning": "The codebase uses camelCase for JavaScript/TypeScript. 'userId' aligns with existing patterns in src/types/user.ts and the API response format."
      },
      "relatedArtifact": {
        "type": "alignment",
        "id": "align-001",
        "title": "Cross-spec naming consistency"
      },
      "impact": {
        "filesAffected": [
          "wavepool/specs/2026-01-21-auth/spec.md",
          "wavepool/specs/2026-01-21-profiles/spec.md"
        ]
      },
      "reviewed": false
    }
  ],
  "stats": {
    "totalDecisions": 2,
    "userDecisions": 1,
    "aiDecisions": 1,
    "pendingReview": 2,
    "byPhase": {
      "shaping": 1,
      "alignment": 1
    }
  }
}
```

#### Decision Log SDK Methods

```typescript
// Access decision log through SDK
const decisions = await wavePool.getDecisions({
  phase: 'alignment',           // Filter by phase
  answeredBy: 'ai',             // Filter by who answered
  reviewed: false,              // Filter by review status
  artifactId: '2026-01-21-auth' // Filter by related artifact
});

// Mark decisions as reviewed
await wavePool.reviewDecision('dec-002', {
  reviewed: true,
  reviewNotes: 'Approved - camelCase is correct for this project'
});

// Export decisions for reporting
const report = await wavePool.exportDecisions({
  format: 'markdown',           // 'json' | 'markdown' | 'csv'
  includeAIReasoning: true
});
```

#### Decision Events

```typescript
// Listen for all decisions
wavePool.on('decision:logged', ({ decision }) => {
  console.log(`Decision logged: ${decision.id}`);
});

// Listen specifically for user answers
wavePool.on('decision:user-answered', ({ decision }) => {
  // Update UI to show user's choice was recorded
});

// Listen specifically for AI decisions
wavePool.on('decision:ai-decided', ({ decision }) => {
  // Optionally show notification that AI made a decision
  if (decision.answer.confidence < 0.8) {
    ui.warn(`AI made low-confidence decision: ${decision.question.prompt}`);
  }
});
```

### SDK Usage Examples

#### Example 1: CLI Usage (Terminal)

```typescript
// packages/cli/src/commands/execute.ts

import { WavePool } from '@wavepool/sdk';
import { TerminalUIAdapter } from '../adapters/TerminalUIAdapter';
import ora from 'ora';
import chalk from 'chalk';

export async function executeCommand(options: CommandOptions) {
  const spinner = ora('Initializing WavePool...').start();

  const wavePool = new WavePool({
    projectDir: options.dir || process.cwd(),
    profile: options.profile,
    adapters: {
      ui: new TerminalUIAdapter(),
    },
  });

  // Wire up events to terminal UI
  wavePool.on('phase:start', ({ phase, itemCount }) => {
    spinner.text = `${phase}: Processing ${itemCount} items...`;
  });

  wavePool.on('batch:progress', ({ completed, total, current }) => {
    spinner.text = `[${completed}/${total}] ${current}`;
  });

  wavePool.on('session:start', ({ task }) => {
    spinner.text = chalk.cyan(`Session: ${task.name}`);
  });

  wavePool.on('interaction:required', async ({ prompt, options, resolve }) => {
    spinner.stop();
    const answer = await promptUser(prompt, options);
    resolve(answer);
    spinner.start();
  });

  try {
    const result = await wavePool.execute({
      specOnly: options.specOnly,
      checkpointAt: options.checkpoint,
    });

    spinner.succeed('Execution complete!');
    console.log(formatResult(result));
  } catch (error) {
    spinner.fail('Execution failed');
    console.error(chalk.red(error.message));
    process.exit(1);
  }
}
```

#### Example 2: Electron App Integration

```typescript
// electron-app/src/main/wavepool-integration.ts

import { WavePool } from '@wavepool/sdk';
import { BrowserWindow, ipcMain } from 'electron';
import { ElectronFileSystemAdapter } from './adapters/ElectronFileSystemAdapter';
import { ElectronUIAdapter } from './adapters/ElectronUIAdapter';

export class WavePoolIntegration {
  private wavePool: WavePool | null = null;
  private mainWindow: BrowserWindow;

  constructor(mainWindow: BrowserWindow) {
    this.mainWindow = mainWindow;
    this.setupIPC();
  }

  private setupIPC() {
    ipcMain.handle('wavepool:init', async (_, projectDir: string) => {
      this.wavePool = new WavePool({
        projectDir,
        adapters: {
          fileSystem: new ElectronFileSystemAdapter(),
          ui: new ElectronUIAdapter(this.mainWindow),
        },
      });

      // Forward all events to renderer process
      this.wavePool.on('*', (eventName, data) => {
        this.mainWindow.webContents.send('wavepool:event', { eventName, data });
      });

      return { success: true };
    });

    ipcMain.handle('wavepool:execute', async (_, options) => {
      if (!this.wavePool) throw new Error('WavePool not initialized');
      return this.wavePool.execute(options);
    });

    ipcMain.handle('wavepool:cancel', async () => {
      this.wavePool?.cancel();
    });

    ipcMain.handle('wavepool:get-roadmap', async () => {
      if (!this.wavePool) throw new Error('WavePool not initialized');
      return this.wavePool.getRoadmap();
    });
  }
}

// In renderer process (React):
// electron-app/src/renderer/hooks/useWavePool.ts

import { useEffect, useState, useCallback } from 'react';
import { ipcRenderer } from 'electron';

export function useWavePool() {
  const [status, setStatus] = useState<'idle' | 'running' | 'error'>('idle');
  const [progress, setProgress] = useState<Progress | null>(null);
  const [roadmap, setRoadmap] = useState<Roadmap | null>(null);

  useEffect(() => {
    const handleEvent = (_, { eventName, data }) => {
      switch (eventName) {
        case 'batch:progress':
          setProgress(data);
          break;
        case 'execute:complete':
          setStatus('idle');
          break;
        case 'execute:error':
          setStatus('error');
          break;
      }
    };

    ipcRenderer.on('wavepool:event', handleEvent);
    return () => ipcRenderer.off('wavepool:event', handleEvent);
  }, []);

  const execute = useCallback(async (projectDir: string, options?: ExecuteOptions) => {
    await ipcRenderer.invoke('wavepool:init', projectDir);
    setStatus('running');
    return ipcRenderer.invoke('wavepool:execute', options);
  }, []);

  const cancel = useCallback(() => {
    ipcRenderer.invoke('wavepool:cancel');
  }, []);

  return { status, progress, roadmap, execute, cancel };
}
```

#### Example 3: Web Application (with Backend Proxy)

```typescript
// web-app/src/services/WavePoolService.ts

import { WavePoolEvents } from '@wavepool/sdk';

/**
 * Web client that communicates with a backend WavePool server.
 * The server runs the actual SDK; the client receives events via WebSocket.
 */
export class WavePoolWebClient {
  private ws: WebSocket;
  private listeners: Map<string, Set<Function>> = new Map();

  constructor(serverUrl: string) {
    this.ws = new WebSocket(serverUrl);
    this.ws.onmessage = (event) => {
      const { eventName, data } = JSON.parse(event.data);
      this.emit(eventName, data);
    };
  }

  on<K extends keyof WavePoolEvents>(
    event: K,
    callback: (data: WavePoolEvents[K]) => void
  ): void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(callback);
  }

  private emit(eventName: string, data: any): void {
    const callbacks = this.listeners.get(eventName);
    callbacks?.forEach(cb => cb(data));
  }

  async execute(projectId: string, options?: ExecuteOptions): Promise<void> {
    this.ws.send(JSON.stringify({
      action: 'execute',
      projectId,
      options
    }));
  }

  async cancel(): Promise<void> {
    this.ws.send(JSON.stringify({ action: 'cancel' }));
  }
}

// React hook for web app
export function useWavePoolWeb(serverUrl: string) {
  const [client] = useState(() => new WavePoolWebClient(serverUrl));
  const [progress, setProgress] = useState<Progress | null>(null);

  useEffect(() => {
    client.on('batch:progress', setProgress);
    client.on('interaction:required', async (data) => {
      // Show modal dialog, then send response back
      const answer = await showInteractionDialog(data);
      client.respond(data.interactionId, answer);
    });
  }, [client]);

  return { client, progress };
}
```

#### Example 4: Headless/CI Usage

```typescript
// ci-script/run-wavepool.ts

import { WavePool } from '@wavepool/sdk';

/**
 * Headless adapter that auto-responds to interactions.
 * Useful for CI/CD pipelines where human input isn't available.
 */
class HeadlessUIAdapter implements UIAdapter {
  private autoResponses: Map<string, string>;

  constructor(responses: Record<string, string>) {
    this.autoResponses = new Map(Object.entries(responses));
  }

  async prompt(options: PromptOptions): Promise<string> {
    const response = this.autoResponses.get(options.name);
    if (!response) {
      throw new Error(`No auto-response configured for: ${options.name}`);
    }
    return response;
  }

  async confirm(message: string): Promise<boolean> {
    // In CI, default to proceeding
    console.log(`[AUTO-CONFIRM] ${message}`);
    return true;
  }

  showProgress(options: ProgressOptions): ProgressHandle {
    console.log(`[PROGRESS] ${options.message}`);
    return {
      update: (msg) => console.log(`[PROGRESS] ${msg}`),
      complete: () => console.log('[COMPLETE]'),
      fail: (err) => console.error(`[FAILED] ${err}`),
    };
  }

  info(message: string): void { console.log(`[INFO] ${message}`); }
  warn(message: string): void { console.warn(`[WARN] ${message}`); }
  error(message: string): void { console.error(`[ERROR] ${message}`); }
}

// CI script
async function main() {
  const wavePool = new WavePool({
    projectDir: process.env.PROJECT_DIR!,
    profile: 'default',
    adapters: {
      ui: new HeadlessUIAdapter({
        'auth-method': 'JWT with refresh tokens',
        'mfa-support': 'yes',
      }),
    },
    orchestration: {
      maxConcurrency: 2,  // Be conservative in CI
    },
  });

  wavePool.on('execute:error', ({ error }) => {
    console.error('Execution failed:', error);
    process.exit(1);
  });

  await wavePool.execute({ specOnly: true });
  console.log('Specs generated successfully');
}

main();
```

---

## Embedding Considerations

### Environment Compatibility Matrix

| Feature | Node.js (CLI) | Electron (Main) | Electron (Renderer) | Browser (Direct) | Browser (via Server) |
|---------|--------------|-----------------|---------------------|------------------|---------------------|
| **File System** | Native `fs` | Native `fs` | Via IPC to main | ❌ No access | Via API |
| **Git Operations** | `simple-git` | `simple-git` | Via IPC to main | `isomorphic-git` | Via API |
| **Claude SDK** | Direct | Direct | Via IPC to main | ❌ CORS issues | Via API |
| **Process Spawning** | Native | Native | Via IPC to main | ❌ No access | Via API |
| **State Persistence** | File system | File system | Via IPC to main | IndexedDB/localStorage | Via API |

### Electron Integration

Electron apps run the SDK in the **main process** (Node.js) and communicate with the renderer (browser) via IPC:

```
┌──────────────────────────────────────────────────────────────────┐
│                        ELECTRON APP                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    MAIN PROCESS (Node.js)                    │ │
│  │                                                              │ │
│  │   @wavepool/sdk                                              │ │
│  │   ├── Uses native fs                                         │ │
│  │   ├── Uses simple-git                                        │ │
│  │   ├── Connects to Claude API directly                        │ │
│  │   └── Emits events → forwarded to renderer                   │ │
│  │                                                              │ │
│  │   ipcMain.handle('wavepool:*', ...) ◄────────────┐           │ │
│  │                                                   │           │ │
│  └───────────────────────────────────────────────────┼──────────┘ │
│                                                      │ IPC        │
│  ┌───────────────────────────────────────────────────┼──────────┐ │
│  │                  RENDERER PROCESS (Browser)       │          │ │
│  │                                                   ▼          │ │
│  │   React/Vue/Svelte UI                                        │ │
│  │   ├── ipcRenderer.invoke('wavepool:execute', ...)            │ │
│  │   ├── ipcRenderer.on('wavepool:event', ...)                  │ │
│  │   └── Displays progress, handles user interactions           │ │
│  │                                                              │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

**Key Considerations for Electron:**

1. **Context Isolation** - Use `contextBridge` to safely expose IPC handlers
2. **Security** - Validate all IPC arguments; don't expose raw file system access
3. **Cancellation** - Support canceling long-running operations from UI
4. **Memory** - Large state objects should be passed by reference or chunked

```typescript
// Electron preload script for secure IPC exposure
// electron-app/src/preload.ts

import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('wavePool', {
  execute: (options) => ipcRenderer.invoke('wavepool:execute', options),
  cancel: () => ipcRenderer.invoke('wavepool:cancel'),
  getRoadmap: () => ipcRenderer.invoke('wavepool:get-roadmap'),

  onEvent: (callback) => {
    const handler = (_, data) => callback(data);
    ipcRenderer.on('wavepool:event', handler);
    return () => ipcRenderer.off('wavepool:event', handler);
  },
});

// Type declarations for renderer
declare global {
  interface Window {
    wavePool: {
      execute: (options?: ExecuteOptions) => Promise<ExecutionResult>;
      cancel: () => Promise<void>;
      getRoadmap: () => Promise<Roadmap>;
      onEvent: (callback: (event: WavePoolEvent) => void) => () => void;
    };
  }
}
```

### Web Application Integration

For web applications, the SDK runs on a **backend server** with the web client connecting via WebSocket or HTTP:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           WEB ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────┐          ┌─────────────────────────────────┐   │
│  │   BROWSER CLIENT    │          │        BACKEND SERVER            │   │
│  │                     │          │                                  │   │
│  │  React/Vue UI       │  WS/HTTP │  Express/Fastify                 │   │
│  │  ├─ WebSocket ─────────────────►  ├─ @wavepool/sdk               │   │
│  │  │  connection      │          │  │  ├─ Full Node.js env         │   │
│  │  │                  │◄─────────┤  │  ├─ Native fs access         │   │
│  │  ├─ Receives events │  Events  │  │  ├─ Git operations           │   │
│  │  │                  │          │  │  └─ Claude API               │   │
│  │  └─ Sends commands  │          │  │                              │   │
│  │     (execute,       │          │  └─ Manages multiple projects   │   │
│  │      cancel, etc.)  │          │      per user                   │   │
│  │                     │          │                                  │   │
│  └─────────────────────┘          └─────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Backend Server Implementation:**

```typescript
// web-server/src/server.ts

import { WebSocketServer } from 'ws';
import { WavePool } from '@wavepool/sdk';

const wss = new WebSocketServer({ port: 8080 });

// Track active sessions per connection
const sessions = new Map<WebSocket, WavePool>();

wss.on('connection', (ws) => {
  ws.on('message', async (message) => {
    const { action, projectId, options } = JSON.parse(message.toString());

    switch (action) {
      case 'init': {
        const projectDir = getProjectDir(projectId); // Map project ID to path
        const wavePool = new WavePool({ projectDir });

        // Forward all events to client
        wavePool.on('*', (eventName, data) => {
          ws.send(JSON.stringify({ type: 'event', eventName, data }));
        });

        // Handle interaction requests
        wavePool.on('interaction:required', async ({ prompt, resolve, reject }) => {
          const interactionId = generateId();
          pendingInteractions.set(interactionId, { resolve, reject });
          ws.send(JSON.stringify({
            type: 'interaction',
            interactionId,
            prompt,
          }));
        });

        sessions.set(ws, wavePool);
        ws.send(JSON.stringify({ type: 'ready' }));
        break;
      }

      case 'execute': {
        const wavePool = sessions.get(ws);
        if (!wavePool) {
          ws.send(JSON.stringify({ type: 'error', message: 'Not initialized' }));
          return;
        }
        try {
          const result = await wavePool.execute(options);
          ws.send(JSON.stringify({ type: 'result', result }));
        } catch (error) {
          ws.send(JSON.stringify({ type: 'error', message: error.message }));
        }
        break;
      }

      case 'respond': {
        const { interactionId, answer } = options;
        const interaction = pendingInteractions.get(interactionId);
        if (interaction) {
          interaction.resolve(answer);
          pendingInteractions.delete(interactionId);
        }
        break;
      }

      case 'cancel': {
        sessions.get(ws)?.cancel();
        break;
      }
    }
  });

  ws.on('close', () => {
    sessions.get(ws)?.cancel();
    sessions.delete(ws);
  });
});
```

### VS Code Extension Integration

VS Code extensions run in a Node.js environment with access to the VS Code API:

```typescript
// vscode-extension/src/extension.ts

import * as vscode from 'vscode';
import { WavePool } from '@wavepool/sdk';

class VSCodeUIAdapter implements UIAdapter {
  async prompt(options: PromptOptions): Promise<string> {
    const result = await vscode.window.showInputBox({
      prompt: options.message,
      placeHolder: options.placeholder,
    });
    if (result === undefined) throw new Error('User cancelled');
    return result;
  }

  async select(options: SelectOptions): Promise<string> {
    const result = await vscode.window.showQuickPick(options.choices, {
      placeHolder: options.message,
    });
    if (!result) throw new Error('User cancelled');
    return result;
  }

  async confirm(message: string): Promise<boolean> {
    const result = await vscode.window.showInformationMessage(
      message,
      'Yes', 'No'
    );
    return result === 'Yes';
  }

  showProgress(options: ProgressOptions): ProgressHandle {
    let resolve: () => void;
    const promise = new Promise<void>(r => resolve = r);

    vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: options.message,
        cancellable: true,
      },
      async (progress, token) => {
        token.onCancellationRequested(() => {
          // Handle cancellation
        });
        await promise;
      }
    );

    return {
      update: (msg) => { /* Update progress */ },
      complete: () => resolve(),
      fail: () => resolve(),
    };
  }

  info(message: string): void {
    vscode.window.showInformationMessage(message);
  }

  warn(message: string): void {
    vscode.window.showWarningMessage(message);
  }

  error(message: string): void {
    vscode.window.showErrorMessage(message);
  }
}

export function activate(context: vscode.ExtensionContext) {
  const outputChannel = vscode.window.createOutputChannel('WavePool');

  const executeCommand = vscode.commands.registerCommand(
    'wavepool.execute',
    async () => {
      const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
      if (!workspaceFolder) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
      }

      const wavePool = new WavePool({
        projectDir: workspaceFolder.uri.fsPath,
        adapters: {
          ui: new VSCodeUIAdapter(),
        },
      });

      wavePool.on('session:progress', ({ message }) => {
        outputChannel.appendLine(message);
      });

      try {
        await wavePool.execute();
        vscode.window.showInformationMessage('WavePool execution complete');
      } catch (error) {
        vscode.window.showErrorMessage(`WavePool failed: ${error.message}`);
      }
    }
  );

  context.subscriptions.push(executeCommand);
}
```

### Browser-Only Mode (Experimental)

For scenarios where a backend isn't available, a limited browser-only mode could work with:
- **Virtual file system** (in-memory or IndexedDB-backed)
- **isomorphic-git** for Git operations on the virtual FS
- **Proxy server** for Claude API calls (to avoid CORS)

This mode is **not recommended** for production but useful for:
- Demos and tutorials
- Offline experimentation
- Sandboxed environments

```typescript
// Browser-only experimental setup
import { WavePool } from '@wavepool/sdk';
import { BrowserFileSystemAdapter } from '@wavepool/sdk/adapters/browser';
import { IsomorphicGitAdapter } from '@wavepool/sdk/adapters/isomorphic-git';
import { ProxiedClaudeAdapter } from '@wavepool/sdk/adapters/proxied-claude';

const wavePool = new WavePool({
  projectDir: '/virtual/project',  // Virtual path
  adapters: {
    fileSystem: new BrowserFileSystemAdapter({
      backend: 'indexeddb',  // or 'memory'
    }),
    git: new IsomorphicGitAdapter({
      fs: browserFS,
      corsProxy: 'https://cors-proxy.example.com',
    }),
    claude: new ProxiedClaudeAdapter({
      proxyUrl: 'https://api-proxy.example.com/claude',
    }),
    ui: new BrowserUIAdapter(),
  },
});
```

---

## Batch Flow with Checkpoints

This section details the "Funnel with Checkpoints" workflow that maximizes parallelism while maintaining coordination through explicit alignment reviews.

### Design Philosophy

**Key principles:**
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
│  │   Alignment Agent checks:                                        │   │
│  │   ├─ Naming conflicts?                                           │   │
│  │   ├─ API inconsistencies?                                        │   │
│  │   ├─ Data model drift?                                           │   │
│  │   ├─ Shared component divergence?                                │   │
│  │   ├─ Dependency ordering issues?                                 │   │
│  │   └─ Scope overlap/duplication?                                  │   │
│  │                                                                  │   │
│  │   User reviews → Agent applies approved changes + cascade check  │   │
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
│  │   Alignment Agent checks:                                        │   │
│  │   ├─ Cross-spec task dependencies correct?                       │   │
│  │   ├─ Shared infrastructure tasks deduplicated?                   │   │
│  │   ├─ Execution order respects dependencies?                      │   │
│  │   ├─ Integration points identified?                              │   │
│  │   └─ Effort estimates reasonable?                                │   │
│  │                                                                  │   │
│  │   User reviews → Agent applies approved changes + cascade check  │   │
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

### Phase Summary

| Phase | Mode | Purpose |
|-------|------|---------|
| 1. Shaping | Sequential | Preserve human judgment, accumulate context |
| 2. Spec Writing | Parallel | Efficiency - all specs written at once |
| Checkpoint 1 | Alignment Review | Catch conflicts before task creation |
| 3. Task Creation | Parallel | Efficiency - all tasks created at once |
| Checkpoint 2 | Alignment Review | Validate cross-spec dependencies |
| 4. Execution | Sequential | Risk-based autonomy, smart drift handling |

### Checkpoint 1: Spec Alignment Review

The alignment agent checks all specs for:

| Category | What to Check | Example Issue |
|----------|---------------|---------------|
| **Naming Conflicts** | Same name, different meaning | Two specs define `UserProfile` model differently |
| **API Inconsistency** | Incompatible interfaces | Spec A: `GET /users/:id`, Spec B: `GET /user/:id` |
| **Data Model Drift** | Schema conflicts | Spec A: `user.email` (string), Spec B: `user.emails` (array) |
| **Shared Components** | Same component, different APIs | Both use `<Button>` but expect different props |
| **Dependency Ordering** | Wrong sequence declared | Spec B depends on A but roadmap doesn't reflect |
| **Scope Overlap** | Duplicate work | Both specs implement user notifications |

### Checkpoint 2: Task Alignment Review

The alignment agent checks all task lists for:

| Category | What to Check | Example Issue |
|----------|---------------|---------------|
| **Cross-Spec Dependencies** | Task A needs Task B from different spec | Spec 2 Task 3 needs Spec 1 Task 5 complete first |
| **Infrastructure Deduplication** | Same setup in multiple specs | Multiple specs create "setup database" task |
| **Execution Order** | Respects roadmap dependencies | Spec B tasks scheduled before Spec A completes |
| **Integration Points** | Where specs connect | API consumer tasks align with API provider tasks |
| **Effort Sanity** | Reasonable estimates | One spec has 50 XL tasks, another has 2 XS |

### Risk Classification for Drift Resolution

During execution, drift is classified by risk level:

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

### Drift Detection Triggers

The orchestrator monitors for drift during execution:

- Implementation creates different API than spec described
- New dependency discovered not in tasks.json
- Task cannot be completed as specified
- Test failures reveal spec assumption was wrong
- Downstream task references something that doesn't exist

### Alignment Schema Additions

#### Addition to `spec-meta.schema.json`:

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

#### Addition to `tasks.schema.json`:

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

#### New file: `alignment-report.schema.json`:

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

    // Create wavepool directory structure
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

1. \`wavepool/product/roadmap.json\` - Current roadmap
2. \`wavepool/product/mission.md\` - Product vision
3. \`wavepool/product/tech-stack.md\` - Technical decisions
4. \`wavepool/product/findings.json\` - Institutional knowledge

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
5. Write structured requirements to \`wavepool/specs/{{specPath}}/planning/requirements.md\`
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
- \`wavepool/standards/global/\` - Universal standards
- \`wavepool/standards/backend/\` - Backend-specific (if applicable)
- \`wavepool/standards/frontend/\` - Frontend-specific (if applicable)

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
2. wavepool/specs/{{specId}}/spec.md - The specification
3. wavepool/specs/{{specId}}/tasks.json - Task breakdown
4. wavepool/standards/ - Coding standards to follow

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
2. wavepool/specs/{{specId}}/spec.md - The specification
3. wavepool/specs/{{specId}}/tasks.json - Task breakdown
4. wavepool/product/tech-stack.md - Technical decisions
5. wavepool/product/findings.json - Patterns and gotchas
6. wavepool/standards/ - Coding standards to follow

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
    const path = this.resolvePath('wavepool/product/roadmap.json');
    return JSON.parse(await fs.readFile(path, 'utf-8'));
  }

  async updateRoadmapItem(id: string, updates: Partial<RoadmapItem>): Promise<void> {
    const roadmap = await this.loadRoadmap();
    const item = roadmap.items.find(i => i.id === id);
    if (!item) throw new Error(`Roadmap item ${id} not found`);

    Object.assign(item, updates);

    await fs.writeFile(
      this.resolvePath('wavepool/product/roadmap.json'),
      JSON.stringify(roadmap, null, 2)
    );
  }

  async loadTasks(specId: string): Promise<TasksFile> {
    const path = this.resolvePath(`wavepool/specs/${specId}/tasks.json`);
    return JSON.parse(await fs.readFile(path, 'utf-8'));
  }

  async appendFindings(findings: Finding[]): Promise<void> {
    const path = this.resolvePath('wavepool/product/findings.json');
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
    const result = await exec('git add wavepool/ && git commit -m ' +
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
  .name('wavepool')
  .description('TypeScript orchestration for AI-driven development')
  .version('1.0.0');

// Profile management
program
  .command('install')
  .description('Install WavePool into a project')
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
    console.log('WavePool installed successfully');
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

$ wavepool execute

[Planning] Validating roadmap...
[Planning] Found 5 items: auth, profiles, dashboard, notifications, settings

[Shaping] Starting sequential shaping with human-in-the-loop...
[Session 1/5] Shaping "auth"...
  > Q1: What authentication methods should be supported?
  < JWT with refresh tokens, OAuth for Google/GitHub
  > Q2: Should we support MFA?
  < Yes, TOTP-based
  ... (user answers questions)
[Session 1/5] Complete. Requirements written to wavepool/specs/2026-01-21-auth/

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

$ wavepool execute

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

$ wavepool spec --parallel

[Shaping] Starting sequential shaping...
... (user answers questions for each item)

[Spec Writing] Starting parallel spec writing...
[Session 1-5] Writing specs... ✓ (5/5)

[Complete] 5 specs created
  auth: wavepool/specs/2026-01-21-auth/
  profiles: wavepool/specs/2026-01-21-profiles/
  dashboard: wavepool/specs/2026-01-21-dashboard/
  notifications: wavepool/specs/2026-01-21-notifications/
  settings: wavepool/specs/2026-01-21-settings/
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

### Phase 1: Foundation & Monorepo Setup

**Goal:** Set up monorepo structure with SDK and CLI packages

1. Initialize monorepo with Turborepo/npm workspaces
2. Create `@wavepool/sdk` package with core types and interfaces
3. Create `@wavepool/cli` package with basic CLI scaffolding
4. Define adapter interfaces (`FileSystemAdapter`, `GitAdapter`, `UIAdapter`, `ClaudeAdapter`)
5. Implement Node.js default adapters for SDK
6. Set up build pipeline with tsup for both packages

**Deliverables:**
- Monorepo structure with `packages/sdk` and `packages/cli`
- SDK exports clean public API (`WavePool`, adapters, types)
- CLI can import and use SDK
- Build produces both ESM and CJS bundles
- Type declarations generated correctly

### Phase 2: Event System & Core SDK

**Goal:** Implement event-driven architecture for SDK

1. Implement typed `EventEmitter` with full event catalog
2. Implement `StateManager` using `FileSystemAdapter` (not direct `fs`)
3. Implement `ProfileInstaller` and `ProfileLoader` in SDK
4. Create prompt template system with bundled templates
5. Export all SDK functionality through clean API

**Deliverables:**
- SDK emits typed events for all operations
- Host applications can subscribe to events
- State operations work through adapter abstraction
- `wavePool.installProfile()` works from SDK
- Prompt templates bundled with SDK package

### Phase 3: Session Management

**Goal:** Spawn and manage Claude Code sessions via SDK

1. Implement `SessionManager` with Claude Agent SDK integration
2. Implement `PromptBuilder` - constructs prompts from templates with variable interpolation
3. Create fresh session pattern (one session per task)
4. Session events emitted for progress tracking
5. Implement basic retry logic with exponential backoff

**Deliverables:**
- SDK can spawn Claude Code sessions programmatically
- Sessions emit `session:start`, `session:progress`, `session:complete` events
- Session runs against target project directory
- Results captured, parsed, and returned

### Phase 4: CLI Integration Layer

**Goal:** Build CLI on top of SDK

1. Implement `TerminalUIAdapter` for interactive terminal UI
2. Wire CLI commands to SDK methods
3. Implement progress visualization (spinners, progress bars)
4. Add interactive prompts for user input
5. Handle `interaction:required` events from SDK

**Deliverables:**
- `wavepool install` works (uses SDK)
- Terminal shows spinners and progress
- Interactive prompts work for shaping phase
- Clean error handling and user feedback

### Phase 5: Lifecycle Phases

**Goal:** Orchestrate planning, specification, implementation phases

1. Implement `PlanningPhase` - roadmap creation
2. Implement `SpecificationPhase` - shaping and spec writing
3. Implement `ImplementationPhase` - task execution with fresh sessions
4. All phases emit appropriate events
5. Cancellation support throughout

**Deliverables:**
- `wavePool.plan()` creates roadmap
- `wavePool.spec()` shapes and writes specs
- `wavePool.implement()` executes tasks
- CLI commands (`wavepool plan`, `wavepool spec`, `wavepool implement`) work

### Phase 6: Batch Processing

**Goal:** Parallel execution and batching

1. Implement `BatchProcessor` with configurable concurrency
2. Add parallel spec writing with `batch:progress` events
3. Add parallel task creation
4. Implement dependency-aware execution ordering
5. Concurrency respects adapter capabilities

**Deliverables:**
- `wavePool.spec({ parallel: true })` writes specs concurrently
- `batch:start`, `batch:progress`, `batch:complete` events emitted
- Multiple Claude sessions run simultaneously
- Dependencies respected in execution order

### Phase 7: Alignment & Checkpoints

**Goal:** Cross-spec coordination and drift detection

1. Implement `AlignmentPhase` - spec and task alignment
2. Add checkpoint system with `interaction:required` events
3. Implement drift detection during execution
4. Add risk-based autonomy (low risk = auto-resolve)
5. Emit `drift:detected` and `alignment:conflict` events

**Deliverables:**
- `wavePool.align('specs')` reviews all specs
- Checkpoints emit events for host to handle
- Drift detected and classified by severity
- CLI shows alignment UI, SDK emits events

### Phase 8: Full Execution & Polish

**Goal:** End-to-end autonomous execution

1. Implement `execute` command for full roadmap
2. Add resume capability from any state
3. Implement comprehensive error handling
4. Add detailed logging and reporting
5. Documentation and examples for both SDK and CLI

**Deliverables:**
- `wavePool.execute()` runs full workflow
- Interrupted runs resume cleanly
- Comprehensive SDK documentation
- Example integrations (Electron, VS Code, Web)

### Phase 9: Optional Adapters & Browser Support

**Goal:** Alternative adapters for non-Node environments

1. Implement `BrowserFileSystemAdapter` (IndexedDB-backed)
2. Implement `IsomorphicGitAdapter` wrapper
3. Implement `ProxiedClaudeAdapter` for CORS workarounds
4. Test in Electron renderer process
5. Create example Electron app

**Deliverables:**
- SDK works in Electron main process out of the box
- Optional adapters available for browser environments
- Example Electron app demonstrates integration
- Documentation for embedding in different environments

---

## Configuration

### wavepool.config.json

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
  "interaction": {
    "questionDeliveryMode": "sequential"
  },
  "autonomy": {
    "planning": "ask",
    "shaping": "ask",
    "specWriting": "ask",
    "taskCreation": "autonomous",
    "alignment": "autonomous",
    "implementation": "autonomous-low-risk"
  },
  "checkpoints": {
    "afterSpecAlignment": true,
    "afterTaskAlignment": true,
    "onHighSeverityDrift": true
  },
  "decisionLog": {
    "enabled": true,
    "path": "wavepool/product/decisions_log.json",
    "includeAIReasoning": true,
    "autoReviewLowConfidence": true,
    "confidenceThreshold": 0.8
  },
  "logging": {
    "level": "info",
    "file": "wavepool.log"
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
| **Question delivery** | Inline in conversation | Sequential or batch (wizard) mode |
| **AI autonomy** | Always asks user | Per-phase configurable autonomy |
| **Decision tracking** | None | Full audit log with artifact refs |

---

## Dependencies

### Monorepo Structure

The project uses npm workspaces (or pnpm/yarn workspaces) for package management:

```json
// Root package.json
{
  "name": "wavepool",
  "private": true,
  "workspaces": [
    "packages/*"
  ],
  "scripts": {
    "build": "turbo run build",
    "test": "turbo run test",
    "lint": "turbo run lint",
    "dev": "turbo run dev"
  },
  "devDependencies": {
    "turbo": "^2.0.0",
    "typescript": "^5.3.0"
  }
}
```

### SDK Package (@wavepool/sdk)

```json
// packages/sdk/package.json
{
  "name": "@wavepool/sdk",
  "version": "1.0.0",
  "description": "WavePool SDK - Embeddable AI orchestration library",
  "main": "./dist/index.js",
  "module": "./dist/index.mjs",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.mjs",
      "require": "./dist/index.js",
      "types": "./dist/index.d.ts"
    },
    "./adapters/*": {
      "import": "./dist/adapters/*.mjs",
      "require": "./dist/adapters/*.js",
      "types": "./dist/adapters/*.d.ts"
    }
  },
  "files": ["dist", "README.md"],
  "sideEffects": false,
  "dependencies": {
    "@anthropic-ai/claude-agent-sdk": "^0.2.14",
    "ajv": "^8.12.0",
    "glob": "^10.3.0",
    "simple-git": "^3.22.0",
    "eventemitter3": "^5.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "tsup": "^8.0.0",
    "typescript": "^5.3.0",
    "vitest": "^1.2.0"
  },
  "peerDependencies": {
    "isomorphic-git": "^1.25.0"
  },
  "peerDependenciesMeta": {
    "isomorphic-git": {
      "optional": true
    }
  }
}
```

### CLI Package (@wavepool/cli)

```json
// packages/cli/package.json
{
  "name": "@wavepool/cli",
  "version": "1.0.0",
  "description": "WavePool CLI - Command-line interface for AI orchestration",
  "bin": {
    "wavepool": "./dist/index.js"
  },
  "files": ["dist", "README.md"],
  "dependencies": {
    "@wavepool/sdk": "workspace:*",
    "commander": "^12.0.0",
    "chalk": "^5.3.0",
    "ora": "^8.0.0",
    "inquirer": "^9.2.0",
    "cli-table3": "^0.6.3"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "tsup": "^8.0.0",
    "typescript": "^5.3.0",
    "vitest": "^1.2.0"
  }
}
```

### Optional Adapters

For browser/Electron environments, additional packages may be needed:

```json
// Optional dependencies for different environments
{
  "optionalDependencies": {
    "isomorphic-git": "^1.25.0",      // Browser git operations
    "lightning-fs": "^4.4.0",          // IndexedDB-backed filesystem
    "memfs": "^4.6.0"                  // In-memory filesystem
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
- [WavePool v3.0.0 Assessment](./assessment-roadmap-spec-workflow.md)
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
2. wavepool/specs/{{specPath}}/planning/requirements.md - Shaped requirements
3. wavepool/product/mission.md - Product vision
4. wavepool/product/tech-stack.md - Technical decisions
5. wavepool/product/findings.json - Relevant patterns

## Output

Write the specification to: wavepool/specs/{{specPath}}/spec.md

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
- `wavepool/standards/global/` - Universal standards

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
├── wavepool/                      # State files (read/written by Claude)
│   ├── product/
│   │   ├── mission.md             # Product vision
│   │   ├── roadmap.json           # Roadmap items with statuses
│   │   ├── tech-stack.md          # Technical decisions
│   │   ├── findings.json          # Institutional knowledge
│   │   └── decisions_log.json     # Decision audit trail
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
└── wavepool.config.json           # Orchestrator configuration
```

## Appendix B.2: TypeScript Project File Locations

```
wavepool/                          # The orchestrator (this project)
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
│   │   ├── standards/             # → Installed to wavepool/standards/
│   │   └── schemas/               # → Installed to wavepool/schemas/
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
       │ wavepool execute  │                      │
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
