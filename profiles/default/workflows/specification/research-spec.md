# Spec Research

## Core Responsibilities

1. **Read Initial Idea**: Load context from spec-meta.json and any existing description
2. **Analyze Product Context**: Understand product mission, roadmap, and how this feature fits
3. **Ask Clarifying Questions**: Ask targeted questions ONE AT A TIME using the TodoWrite tool
4. **Process Answers**: Analyze responses and any provided visuals
5. **Ask Follow-ups**: Based on answers and visual analysis if needed
6. **Save Requirements**: Document the requirements gathered
7. **Update spec-meta.json**: Mark spec as shaped

## Workflow

### Step 1: Read Initial Context

Read `agent-os/specs/[this-spec]/spec-meta.json` to understand:
- The spec title and ID
- The linked roadmap item (if any)
- Current status

If there's a `roadmapItemId`, read `agent-os/product/roadmap.json` to get the full description of the feature from the roadmap.

### Step 2: Analyze Product Context

Before generating questions, understand the broader product context:

1. **Read Product Mission**: Load `agent-os/product/mission.md` to understand:
   - The product's overall mission and purpose
   - Target users and their primary use cases
   - Core problems the product aims to solve

2. **Read Product Roadmap**: Load `agent-os/product/roadmap.json` to understand:
   - Features already completed (status: "completed")
   - The current state of the product
   - Where this new feature fits in the broader roadmap
   - Dependencies and related features

3. **Read Product Tech Stack**: Load `agent-os/product/tech-stack.md` to understand:
   - Technologies and frameworks in use
   - Technical constraints and capabilities

### Step 3: Plan Your Questions

Based on the initial idea and product context, plan 4-8 targeted questions that explore requirements. Structure your questions to:

- Propose sensible assumptions based on best practices
- Frame questions as "I'm assuming X, is that correct?"
- Make it easy for users to confirm or provide alternatives
- Cover scope, technical approach, and edge cases
- End with questions about exclusions, existing code reuse, and visual assets

**Create a mental list of questions you need to ask. You will ask them ONE AT A TIME.**

### Step 4: Ask Questions Interactively (One at a Time)

**CRITICAL: Use the `AskUserQuestion` tool to ask each question individually and wait for the user's response before proceeding to the next question.**

For each question in your list:

1. Use `AskUserQuestion` with a clear, focused question
2. Wait for the user's response
3. Record the answer
4. If the answer raises new questions or needs clarification, ask a follow-up before moving to the next planned question
5. Proceed to the next question

**Question sequence should follow this pattern:**

```
Question 1: [Core functionality question]
"I'm assuming [specific assumption about the main feature]. Is that correct, or would you prefer [alternative]?"

Question 2: [User interaction question]  
"For [specific interaction], I'm thinking [approach]. Does that align with what you had in mind?"

Question 3: [Technical approach question]
"Should we [technical decision]? Or do you have a different preference?"

Question 4: [Scope/edge cases question]
"What should happen when [edge case]? I'd suggest [default behavior]."

Question 5: [Exclusions question]
"Is there anything that should explicitly NOT be included in this feature? Any future enhancements we should defer?"

Question 6: [Existing code reuse question]
"Are there existing features in your codebase with similar patterns we should reference? For example:
- Similar UI components
- Comparable page layouts
- Related backend logic
- Existing models or controllers
Please provide file/folder paths if they exist."

Question 7: [Visual assets question]
"Do you have any design mockups, wireframes, or screenshots? If yes, please add them to: agent-os/specs/[this-spec]/planning/visuals/"

Question 8: [Impact analysis - for refactoring/modification tasks]
"If this feature involves changing existing constants, types, or shared code, I need to identify ALL affected areas to avoid missing critical updates:
- Are there any OTHER packages or modules that define or use the same constants/types?
- Are there any hardcoded values in the codebase that should be updated?
- Which areas beyond the obvious ones might be affected? (e.g., background jobs, utilities, tests)
Please list any areas you know use the affected code."
```

**Adapt questions based on previous answers.** If an answer reveals something that changes subsequent questions, adjust accordingly.

### Step 5: Check for Visual Assets

After all questions are answered, **ALWAYS check for visual assets regardless of what the user said:**

```bash
ls -la agent-os/specs/[this-spec]/planning/visuals/ 2>/dev/null | grep -E '\.(png|jpg|jpeg|gif|svg|pdf)$' || echo "No visual files found"
```

If visual files are found:
- Analyze each visual file
- Note key design elements, patterns, and user flows
- Check filenames for low-fidelity indicators (lofi, wireframe, sketch)
- If visuals reveal questions not yet addressed, use `AskUserQuestion` to ask follow-up questions

### Step 6: Ask Follow-up Questions (if needed)

Use `AskUserQuestion` for any follow-ups based on:
- Visuals found that weren't discussed
- Vague answers needing clarification
- Gaps in technical details
- Unclear scope boundaries

Ask follow-ups one at a time, just like the initial questions.

### Step 7: Save Complete Requirements

Create `agent-os/specs/[this-spec]/planning/requirements.md` with all gathered information:

```markdown
# Spec Requirements: [Spec Title]

## Roadmap Link
- **Roadmap Item:** [roadmap-item-id] - [title]
- **Priority:** [priority from roadmap]
- **Effort Estimate:** [effort from roadmap]
- **Dependencies:** [list from roadmap]

## Initial Description
[Description from roadmap or user]

## Requirements Discussion

### Questions & Answers

**Q1:** [Question asked]
**A:** [User's answer]

**Q2:** [Question asked]
**A:** [User's answer]

[Continue for all questions asked during the interactive session]

### Existing Code to Reference
[List of paths/features user identified, or "None identified"]

### Impact Analysis
[Based on user's response about affected areas - CRITICAL for refactoring tasks]

**Affected Areas Identified:**
- Package/Module: [Name] - Reason: [why it's affected]
- Hardcoded values: [locations mentioned by user]
- Additional areas: [other modules mentioned by user]

[If this is a new feature (not refactoring)]
No additional impact areas identified - new feature implementation.

## Visual Assets

### Files Provided
[List files found in visuals/, with descriptions from analysis]

### Visual Insights
[Key observations from visual analysis]

## Requirements Summary

### Functional Requirements
- [Requirement 1]
- [Requirement 2]

### Scope Boundaries

**In Scope:**
- [What will be built]

**Out of Scope:**
- [What won't be built]

### Technical Considerations
- [Any technical notes from discussion]
```

### Step 8: Update spec-meta.json

Update `agent-os/specs/[this-spec]/spec-meta.json`:

1. Set `status` to `"shaped"`
2. Set `shapedAt` to current ISO timestamp
3. Set `files.hasRequirements` to `true`
4. Update `files.hasVisuals` and `files.visualCount` based on visuals found

### Step 9: Output Completion

```
Requirements research complete!

✅ Processed [X] clarifying questions
✅ Visual check: [Found Y files / No files found]
✅ Reusability: [Identified Z similar features / None identified]
✅ Requirements documented
✅ spec-meta.json updated (status: shaped)

Requirements saved to: `agent-os/specs/[this-spec]/planning/requirements.md`

Ready for specification creation. Run /write-spec to continue.
```

## Important Constraints

- **ALWAYS use `AskUserQuestion` to ask questions one at a time** - never dump all questions at once
- **Wait for each response** before asking the next question
- **ALWAYS ask about impact analysis for refactoring tasks** - which other areas use the same constants/types
- Adapt subsequent questions based on previous answers
- Always run visual check after all questions are answered
- Always update spec-meta.json after completing requirements
- Document the roadmap linkage in requirements.md
- Document all affected areas mentioned by user for spec-writer's impact analysis
- Save user's exact answers, not interpretations
- Keep follow-ups focused and ask them one at a time as well
