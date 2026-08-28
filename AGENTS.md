# MiniNotch Development Instructions

## Project

MiniNotch is a native macOS application that extends the MacBook notch with
context-aware activities.

Before making architectural or feature changes, always read:

- `README.md`
- `ROADMAP.md`

`ROADMAP.md` is the source of truth for planned features and implementation order.

---

## Product principles

MiniNotch should remain:

- small
- native
- fast
- context-aware
- event-driven
- visually consistent with macOS

Do not turn MiniNotch into a generic dashboard or an overloaded widget collection.

The core product idea is:

> MiniNotch shows exactly what is important right now.

Temporary system events may temporarily replace lower-priority content and should
return to the previous/default activity afterward.

---

## Scope rules

Implement roadmap items one at a time unless the user explicitly requests a larger
scope.

Do not automatically implement later roadmap items just because they are described
in `ROADMAP.md`.

Only modify code required for the explicitly requested issue or milestone.

If you notice a possible improvement outside the requested scope:

1. Do not implement it automatically.
2. Mention it in the final summary as a possible follow-up.

Avoid unrelated refactors.

---

## Before implementation

For every roadmap issue:

1. Read the relevant sections of `README.md` and `ROADMAP.md`.
2. Inspect the existing implementation before changing it.
3. Identify the smallest set of affected files/components.
4. Understand how the current Media, Codex, window, hover and notch state work.
5. Preserve existing behavior unless the roadmap item explicitly changes it.
6. Prefer extending existing architecture over duplicating logic.

Do not assume an architecture from the roadmap if the existing code requires a
slightly different implementation.

Use the roadmap as the desired behavior and architecture direction, but integrate it
cleanly into the real codebase.

---

## Architecture

Temporary UI events should use the shared `NotchActivity` / `ActivityManager`
architecture once those components exist.

Do not introduce feature-specific presentation state when the shared activity system
can handle the requirement.

Prefer clear ownership of state.

Avoid:

- duplicated state
- multiple competing sources of truth
- feature-specific window managers
- feature-specific animation engines
- unnecessary global singletons
- abstractions that do not yet solve a real problem

Create abstractions only when they make the current implementation simpler or are
explicitly required by the current roadmap item.

---

## Activity model

The long-term activity flow should support behavior similar to:

```text
MEDIA
  │
  │ temporary event
  ▼
VOLUME / BATTERY / TIMER / CODEX / ...
  │
  │ activity finishes
  ▼
MEDIA
```

Higher-priority activities should be able to temporarily replace lower-priority
activities.

Persistent/default activities such as Media must not be accidentally dismissed by
temporary activity lifecycle logic.

The activity system should eventually support:

- priorities
- temporary activities
- persistent activities
- automatic dismissal
- returning to the previous/default activity
- shared transitions
- disabled activities
- compact-first presentation

Implement only the parts required by the currently requested roadmap issue.

---

## UI and UX

Preserve the existing MiniNotch visual language.

New activities should be designed **compact first**.

Example:

```text
┌────────────────────────┐
│ 🔊  ███████░░   72 %   │
└────────────────────────┘
```

Only add an expanded view if it provides useful information or interaction.

Avoid unnecessary visual noise.

Do not add permanent information merely because it is available.

Temporary information should normally disappear automatically after it is no longer
relevant.

Animations should feel native and subtle.

Respect macOS accessibility preferences such as Reduce Motion when that support is
implemented.

---

## Swift / SwiftUI guidelines

Prefer:

- native Swift
- SwiftUI where appropriate
- Apple frameworks and public macOS APIs
- structured concurrency
- clear data flow
- small focused types
- dependency injection where it improves testability
- event-driven APIs

Avoid:

- unnecessary third-party dependencies
- private APIs unless the project already intentionally relies on them and there is
  no reasonable supported alternative
- polling when an event/callback/notification API exists
- force unwraps where failure is realistically possible
- unnecessary `AnyView`
- giant observable objects containing unrelated state

Keep code readable and consistent with the existing project style.

Do not introduce a new architectural pattern across the whole project unless the
current roadmap issue actually requires it.

---

## Performance

MiniNotch should consume as few resources as possible while idle.

Prefer event-driven behavior over polling.

Avoid:

- unnecessary repeating timers
- unnecessary observers
- repeated artwork loading
- repeated expensive system queries
- work for features that are disabled
- unnecessary view updates

Where appropriate:

- cache media artwork
- remove observers when no longer needed
- stop background work when a feature is disabled
- update published state only when values actually change

---

## macOS behavior

Changes must consider:

- MacBook built-in display
- external displays
- display connect/disconnect
- Spaces
- fullscreen apps
- hover state
- notch expansion/collapse
- app activation behavior
- menu bar utility behavior

Do not knowingly break existing multi-monitor or notch positioning behavior while
implementing unrelated features.

---

## Testing

After each implementation:

1. Build the application.
2. Run all existing relevant tests.
3. Add tests for new non-trivial logic where reasonable.
4. Fix errors introduced by the change.
5. Fix new warnings introduced by the change where practical.
6. Review the diff for accidental unrelated changes.

Architecture and state-management logic should receive unit tests whenever possible.

Examples of logic that should be tested:

```text
ActivityManager

✓ highest priority wins
✓ temporary activity can expire
✓ persistent activity remains active
✓ previous/default activity returns
✓ disabled activity is ignored
✓ replacing an activity does not corrupt state
```

Do not claim the build or tests pass unless they were actually executed successfully.

If a build or test cannot be run in the current environment, state that explicitly.

---

## Roadmap workflow

`ROADMAP.md` acts as the project backlog.

When an explicitly requested roadmap item is fully implemented and verified:

1. Change its checkbox from `[ ]` to `[x]`.
2. Do not mark adjacent or partially implemented items as complete.
3. Do not change milestone scope without explicit instruction.

Example:

```markdown
- [x] `[Architecture] Introduce NotchActivity protocol`
- [ ] `[Architecture] Add ActivityManager`
```

Only check an item when its intended behavior is actually implemented.

---

## Completion checklist

Before finishing any implementation task, verify:

```text
[ ] Requested roadmap item implemented
[ ] Existing behavior preserved
[ ] No unrelated feature implemented
[ ] Project builds successfully
[ ] Relevant tests pass
[ ] New logic tested where useful
[ ] Diff reviewed
[ ] ROADMAP.md updated if item is complete
```

---

## Final response format

After completing an implementation, provide a concise summary containing:

### Implemented

What was added or changed.

### Files changed

List the important changed files and their purpose.

### Verification

State exactly which build/tests were executed and whether they passed.

### Roadmap

State which `ROADMAP.md` item was marked complete.

### Follow-up

Mention the next logical roadmap item, but do not implement it unless explicitly
requested.

---

## Important

Do not implement the entire roadmap in one pass.

Do not continue to the next roadmap issue automatically.

Stop after the requested issue is implemented, verified and documented.
