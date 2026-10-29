# Modernization worklog

This file records the work for `doc/adr/001_modernize_and_sync_with_katex.md`.
Add new entries at the end. Do not edit old entries. If an old entry is
wrong, add a new entry that corrects it.

Entry format:

```
## YYYY-MM-DD — <workplan step(s)> — <short title>
- Done: what changed, with commit hashes.
- Numbers: corpus size, divergence count, test and analyze results.
- Found: facts that the next person needs.
- Next: the next step.
```

## Reference

- KaTeX checkout: `~/dev/KaTeX`. Use `git -C ~/dev/KaTeX checkout <tag>`
  before you generate the corpus.
- Dart parser base: KaTeX `c2e5a289` (2020-05-30).
- Pinned KaTeX tag: `v0.19.1` (commit `8000fbd4`), not yet written to
  `tool/katex_sync/katex_version`.
- KaTeX expected results without a build:
  `npm pack katex@<version>`, then `require('./package/dist/katex.js').__parse(tex, settings)`.

## Status

| Metric | Value | Date |
|--------|-------|------|
| Workplan step | 0 (not started) | 2026-10-29 |
| `flutter analyze` issues | 63 | 2026-10-29 |
| `flutter test` | 410 pass, 8 fail (all SelectableMath) | 2026-10-29 |
| Corpus cases | not generated | — |
| Divergences (`not-ported`) | not measured | — |

## 2026-10-29 — none — Baseline and ADR draft
- Done: cloned KaTeX to `~/dev/KaTeX`. Wrote the ADR draft and this file.
- Numbers: Flutter 3.47.1. `flutter analyze`: 63 issues (31
  `directives_ordering`, 20 deprecations, 2 warnings in selection code).
  `flutter test`: 410 pass, 8 fail.
- Found: the macro set dates the port to KaTeX `c2e5a289`. KaTeX has 255
  commits to `src/` and `contrib/mhchem/` after it. KaTeX `v0.13.0`
  replaced `greediness` (#2085, #2134). The Dart parser still uses it.
- Found: the open edit to `analysis_options.yaml` and the untracked
  `example/ios/Flutter/ephemeral/` existed before this work.
- Next: owner review of the ADR, mainly D12 (remove SelectableMath). Then
  workplan step 1.
