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
| Workplan step | Phase 0 done (steps 1–8); next: step 9 | 2026-10-29 |
| `flutter analyze` issues | 0 | 2026-10-29 |
| `flutter test` | 403 pass, 1 skip, 0 fail | 2026-10-29 |
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

## 2026-10-29 — steps 1–8 — Phase 0: trustworthy tests
- Done: `5968c71` step 1. `c12a5ea` D12, D13 and step 2 (removed
  SelectableMath and its selection, controller and EditableLine code;
  records replace `tuple`; `provider` and `canvas_kit` gone;
  `flutter_lints` with `strict-casts` and `strict-raw-types`). `0691b07`
  step 3. `56b25f0` step 4. `83fc5c2` step 5. `a243113` steps 6, 7.
- Numbers: analyze 63 → 0. Tests 410 pass / 8 fail → 403 pass / 1 skip.
  37 goldens, regenerated on macOS, Flutter 3.47.1.
- Found: `dart fix` removed library names but left `part of <name>;` in
  the function files. Converted to `part of '<uri>';`. It also deleted two
  imports that only looked unused while the part files were broken.
- Found: the new macOS goldens look heavier than the 2020 Windows images.
  This is rasterization, not bold fonts: a run with no Bold font files
  loaded gives the same image. I reviewed every image by eye.
- Found: on macOS, golden file names are case-insensitive.
  `\Overrightarrow` and `\overrightarrow` wrote the same file. The accent
  goldens now use `accent__overrightarrow.png` for capitals.
- Found (bugs fixed): the TeX encoder wrote alpha in `\textcolor`
  (`#ffff0000`). `Math` crashed when no `DefaultTextStyle` gave a size or
  color. `Math` ignored nonlinear text scaling (`textScaleFactorOf`).
- Found (divergence, not fixed): with `strict: error`, the Dart parser
  rejects `\text{é}`. KaTeX accepts it. The `toParse` matcher ignored its
  settings, so the spec test passed by accident. The test is now skipped
  with a reason. The conformance corpus will track it.
- Found: unknown-symbol errors report UTF-16 code units (an emoji gives
  `(55357)`), and the underlined excerpt splits surrogate pairs. KaTeX
  does the same, so this is not a divergence.
- Found: harness self-check. A temporary test confirmed that
  `testTexToRenderLike` fails on different output and on parse errors,
  that a wrong golden fails, and that `toParse` uses its settings.
- Next: README for this fork. Then step 9 (jest recording hook).
