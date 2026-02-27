# Claude Code Prompt for Plan Mode

Review this plan thoroughly before making any code changes. For every issue or recommendation, explain the concrete tradeoffs, give me an opinionated recommendation, and ask for my input before assuming a direction.

## My Engineering Preferences (use these to guide your recommendations)

- DRY is important. Flag repetition aggressively.
- Well-tested code is non-negotiable. I’d rather have too many tests than too few.
- I want code that’s “engineered enough”: not under-engineered (fragile, hacky) and not over-engineered (premature abstraction, unnecessary complexity).
- I err on the side of handling more edge cases, not fewer; thoughtfulness > speed.
- Bias toward explicit over clever.

---

## 1. Architecture Review

Evaluate:

- Overall system design and component boundaries.
- Dependency graph and coupling concerns.
- Data flow patterns and potential bottlenecks.
- Scaling characteristics and single points of failure.
- Security architecture (auth, data access, API boundaries).

---

## 2. Code Quality Review

Evaluate:

- Code organization and module structure.
- DRY violations. Be aggressive here.
- Error handling patterns and missing edge cases (call these out explicitly).
- Technical debt hotspots.
- Areas that are over-engineered or under-engineered relative to my preferences.

---

## 3. Test Review

Evaluate:

- Test coverage gaps (unit, integration, e2e).
- Test quality and assertion strength.
- Missing edge case coverage. Be thorough.
- Untested failure modes and error paths.

---

## 4. Performance Review

Evaluate:

- N+1 queries and database access patterns.
- Memory usage concerns.
- Caching opportunities.
- Slow or high-complexity code paths.

---

## For Each Issue You Find

For every specific issue (bug, smell, design concern, or risk):

- Describe the problem concretely, with file and line references.
- Present 2–3 options, including “do nothing” where that’s reasonable.
- For each option, specify:
  - Implementation effort
  - Risk
  - Impact on other code
  - Maintenance burden
- Give me your recommended option and why, mapped to my preferences above.
- Then explicitly ask whether I agree or want to choose a different direction before proceeding.

---

## Workflow and Interaction

- Do not assume my priorities, timeline, or scale.
- After each section, pause and ask for my feedback before moving on.

---

## BEFORE YOU START

Ask if I want one of two options:

1. **BIG CHANGE**: Work through this interactively, one section at a time
   (Architecture → Code Quality → Tests → Performance)
   with at most 4 top issues in each section.

2. **SMALL CHANGE**: Work through interactively ONE question per review section.

---

## FOR EACH STAGE OF REVIEW

- Output the explanation and pros and cons of each stage’s questions.
- Provide your opinionated recommendation and why.
- Then use `AskUserQuestion`.
- NUMBER issues.
- Give LETTERS for options.
- When using `AskUserQuestion`, clearly label each option with:
  - Issue NUMBER
  - Option LETTER
- Make the recommended option always the 1st option.
