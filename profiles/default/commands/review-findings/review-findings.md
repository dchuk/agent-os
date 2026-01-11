# Review Findings Command

Review and maintain the findings database, cleaning up obsolete entries and updating AGENTS.md.

## When to Use

- After completing several specs
- Monthly maintenance
- When findings.json has grown large
- Before starting a new development phase

## Process

Use the **review-findings** workflow to:

1. Analyze all active findings for validity
2. Identify duplicates and merge candidates
3. Adjust confidence levels based on confirmation counts
4. Archive obsolete findings
5. Regenerate the AGENTS.md findings section

{{workflows/maintenance/review-findings}}
