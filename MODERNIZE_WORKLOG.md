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
- Pinned KaTeX tag: `v0.19.1` (commit `8000fbd4`), in
  `tool/katex_sync/katex_version`.
- Regenerate the corpus: `git -C ~/dev/KaTeX checkout v0.19.1`, then
  `dart run tool/katex_sync/katex_sync.dart generate --katex ~/dev/KaTeX`.
- Update the divergence lists after a parser change:
  `flutter test test/katex_conformance --dart-define=KATEX_UPDATE=true`.
- Commits to port for each file:
  `dart run tool/katex_sync/katex_sync.dart status --katex ~/dev/KaTeX`.
- KaTeX expected results without a build:
  `npm pack katex@<version>`, then `require('./package/dist/katex.js').__parse(tex, settings)`.

## Status

| Metric | Value | Date |
|--------|-------|------|
| Workplan step | Phase 1 done (steps 9–15); next: step 16 | 2026-10-29 |
| `flutter analyze` issues | 0 | 2026-10-29 |
| `flutter test` | 408 pass, 2 skip, 0 fail | 2026-10-29 |
| Corpus cases (KaTeX v0.19.1) | 1696 (1660 portable) | 2026-10-29 |
| Parse divergences | 366 (309 `not-ported`, 57 `trust`) | 2026-10-29 |
| Render failures | 18 of 992 accepted cases | 2026-10-29 |

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

## 2026-10-29 — steps 9–15 — Phase 1: conformance harness
- Done: `efaa14b` steps 9–13, `68318c0` steps 14–15. ADR section 5
  updated to match, status ACCEPTED.
- Numbers: the KaTeX jest suite (1341 tests, 8 suites) makes 1991
  `parseTree` calls with a string input. They give 1696 distinct cases:
  1376 accepted, 320 rejected. 36 are not portable (function settings or
  non-string macros). Of 1660 portable cases, 1294 agree with Dart.
  `status`: 49 headers, all behind v0.19.1; `src/environments/array.ts`
  (33 commits), `src/macros.ts` (27) and `src/Parser.ts` (26) lead.
- Found: KaTeX babel-jest transforms a setup file outside the checkout
  and then cannot resolve `@babel/runtime`. `generate` copies the hook
  into the checkout and deletes it after the run.
- Found: `ss_data.yaml` gives `display: 1`. The first corpus had
  `displayMode: 1` and the Dart test crashed on a cast. The hook now
  records booleans.
- Found: the most frequent "KaTeX accepts, Dart rejects" causes:
  `\def` 28, `\smash` 26, `\gdef` 14, `\mathllap` 10, strict unicode 10,
  `\@binrel` 9, `\mathreflectbox` 8, `\mapsfrom` 7, `\let` 6, `\pmb` 6,
  `matrix*` 5, `CD` 5, `align` 5.
- Found: 9 "Dart accepts, KaTeX rejects" cases. Examples:
  `\raisebox5pt{text}`, `\kern2\relax em`, `hello \cr world`,
  `\@char{\text{2}}`, `\begin{alignedat}{\text{2}}`.
- Found: 2 Dart crashes (not ParseException): `\sum_{\substack{}}`
  (RangeError) and `\char"110000` (RangeError).
- Found (high impact): a top-level `\\` or `\newline` (`x\\y`) parses
  but does not build ("Temporary node CrNode encountered"). In Telosnex,
  such math falls back to raw text. 8 of the 18 render failures have this
  cause. Others: `\begin{matrix}\end{matrix}` (RangeError), and
  RenderResetDimension constraint assertions with `\binom` and
  `\left\{\rule...\right.`.
- Next: step 16, the parser core port in D8 order, starting with
  `src/Lexer.ts`.
