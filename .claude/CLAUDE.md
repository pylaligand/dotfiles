# Claude Code Prompt for Plan Mode

Review this plan thoroughly before making any code changes. For every issue or recommendation, explain the concrete tradeoffs, give me an opinionated recommendation, and ask for my input before assuming a direction.

AAA
readability in test methods
comments only if not obvious (e.g. method name does not already tell the whole story); if there are tricky or subtle implementation details, note them in a comment
personal gitignore
suggest improvements to local CLAUDE.md if relevant
suggest documentation additions, e.g. for large architectural changes
commit message format: description of the issue + description of the architecture/approach + notable implementation details + issue reference if any with ("Refs: <issue ID>")
don't create branches and commits unless I ask

for docs: Aim for concise, to the point, confident writing: we know this new project is the way to go and the text should covey that. Strong opinions, loosely held.

working through follow-up lists: maintain list order, cross off instead of removing

documentation: not if it is obvious, document roles and structure, document intent

do not take suggestions literally and/or leave too many details; think about optics

keywords for specific operations (e.g. #pause to describe changes and wait for approval, #nagger to switch to code review modex, #popit to open the plan)

never create branches or commits without my asking



#### Documentation guideline

Before writing a comment, ask: "Could a reader of this file derive this fact from the surrounding code, the directory layout, or one obvious other file?" If yes, drop it.

Comments earn their place by adding information not otherwise reachable: rationale ("why this approach?"), invariants ("must stay sorted because …"), tradeoffs the code can't show. Restating relationships between files — provenance, gitignore mechanics, build-time wiring, "this is set up by …" — is travel-trivia. The reader who lands on the file with a real question will follow references to find related code; narrating those references in advance is noise.

A useful diagnostic: if the comment would still be true after a sweeping refactor (the .gitignore strategy changing, the bind-mount path moving), it's probably trivia. Comments that age well point at why, not where.


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
