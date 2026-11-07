---
status: accepted
date: 2026-09-10
deciders: maintainer
---
# 0009. Non-secret docs live in the public repo, with code

## Context and problem statement

Documentation and conventions were split across two repos in a way that didn't match who reads
them: the public `NewTube/` repo (code, what cloud agents like Copilot/Codex can see) had
sparse, sometimes-wrong instruction files, while the private `SmartTubeIOSPrivate/` repo held the
bulk of conventions, architecture notes, and the modernization plan itself — invisible to any
agent that only has the public checkout. `docs/modernization/PLAN.md` DEC-2 asks whether to move
non-secret docs into the public repo.

## Decision

Yes — non-secret docs (conventions, architecture, ADRs, how-tos, the modernization plan and
workstream files, the task index) move to the public repo under `docs/`, per WS2-T2.6. The
private repo keeps only `secrets/`, `setup.sh`, and anything genuinely private (`docs/private/`,
`docs/archive/`).

## Consequences

- Good: cloud agents (Copilot, Codex, any tool that only clones the public repo) can now see the
  same conventions, architecture docs, and plan a local agent sees — no more acting on
  contradictory or absent guidance.
- Good: docs live next to the code they describe, making "truthful docs or no docs" (PLAN §1
  Principle 5) enforceable by the same PR review that changes the code.
- Bad: this repo's own program-planning artifact (`docs/modernization/`) is, at the time of this
  ADR, still in the private repo pending WS2-T2.6 — a known, tracked gap, not an oversight
  (`docs/README.md`'s "Not yet written" section documents it).

## Alternatives considered

- **Keep everything in the private repo, give public agents a pointer doc**: this is the
  DEC-2 fallback the plan itself describes ("If the maintainer overrides, execute the same
  structure inside the private repo and add a public `docs/README.md` that says where
  conventions live") — not chosen, since it leaves cloud agents unable to actually read the
  conventions, only know that conventions exist somewhere they can't see.
