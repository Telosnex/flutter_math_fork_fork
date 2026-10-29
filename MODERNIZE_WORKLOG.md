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
| Workplan step | 16: Groups 1 and 2 done; Group 3 left (listed in divergences.json) | 2026-10-29 |
| `flutter analyze` issues | 0 | 2026-10-29 |
| `flutter test` | VM 551 pass / 1 skip; Chrome 323 pass / 62 skip | 2026-10-29 |
| Corpus cases (KaTeX v0.19.1) | 1696 (1660 portable) | 2026-10-29 |
| Parse divergences | 92 (34 `not-ported`, 57 `trust`, 1 `setting`) | 2026-10-29 |
| Render failures | 2 of 1252 accepted cases (both test-view size) | 2026-10-29 |

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

## 2026-10-29 — step 16 — Lexer, Namespace, MacroExpander
- Done: Lexer, Namespace and MacroExpander headers are now
  `@ v0.19.1`. New unit tests: `test/lexer_test.dart`,
  `test/namespace_test.dart`, `test/macro_expander_test.dart`.
- Lexer: control space (#2877), `~` catcode 13 (#2949), `\operatorname`
  as a macro over `\operatorname@` / `\operatornamewithlimits` (#2984;
  operator_name.dart, macros.dart and the encoder changed with it; the
  encoder has a new `specName` for commands that are macros). `lex()` uses
  `matchAsPrefix` at the current position.
- Namespace: fixed a bug where two local sets in one group restored the
  wrong value. Added `set(name, null)` and `endGroups()`.
- MacroExpander: fixed an inverted `isDefined` test in
  `expandOnce(expandableOnly)`. That fixed 2 divergences
  (`\noexpand\foo y`, `\expandafter\foo\noexpand\foo`). Added
  delimited arguments, `scanArgument`, `countExpansion`, `expandTokens`.
- Numbers: divergences 366 → 364. Render failures unchanged (18).
- Found: two Dart divergences remain in MacroExpander, and the file says
  so. (1) `\relax` is dropped in `expandNextToken`. KaTeX v0.19.1 has a
  `\relax` function that makes an "internal" node, which also ends a
  size argument: KaTeX rejects `\kern2\relax em`, Dart accepts it.
  (2) `isExpandable` has no `primitive` check; FunctionSpec has no such
  flag. Both close with the Parser and defineFunction ports.
- Next: `src/Parser.ts` with `src/defineFunction.ts`: `allowedInArgument`
  in place of `greediness` (#2134), argument parsing through
  `scanArgument` (#2085), "internal" nodes and `\relax`. Then `def.ts`
  (`\def` 28, `\gdef` 14, `\let` 6, `\global` 4 cases).
- Next (separate, high user impact): top-level `\\` and `\newline`
  parse but do not build (8 render failures). In Telosnex this shows raw
  LaTeX.

## 2026-10-29 — blocked — local master and origin/master diverged
- Found: `origin/master` has 16 commits (2026-10-28/29, `8547280` to
  `5a83619`) that the local checkout did not have when this work began.
  Local `master` is 16 ahead and 16 behind. Nothing is pushed.
- Overlap: origin fixed SelectableMath (`8547280`); this branch removes
  it (D12). Origin regenerated goldens on Windows with CI from
  telosnex_ci_tools (`799a65c`, `8ad2698`); this branch makes goldens on
  macOS (D10, D11). Both made the analyzer clean and made render-alike
  tests compare in memory. `git merge-tree` lists conflicts in
  analysis_options.yaml, helper.dart, parser.dart, math.dart,
  syntax_tree.dart, style.dart, svg_string.dart, the selection files,
  and all golden images.
- Next: owner decides on D10, D11 and D12 given origin's direction, then
  rebase this branch onto origin/master.

## 2026-10-29 — merge — origin/master merged, blocker resolved
- Decision (owner): keep origin's CI; ADR decisions win (no
  SelectableMath, goldens on macOS).
- Done: `3921065` merges origin/master. Kept from origin: unit.yml and
  integration.yml (telosnex_ci_tools v0.5.3), the ResetDimension accent fix
  (`55e52e7`), web measurement encoding (`8353d3c`), web test support.
  Dropped: origin's SelectableMath fixes, Windows goldens, and this
  branch's ci.yml. ADR D10, D11 and the README match.
- Numbers: VM 426 pass, 2 skip. Chrome dart2js and dart2wasm: 360 pass,
  62 skip (render-alike tests need toImage; conformance tests are
  @TestOn('vm')). `dart format` check and `analyze --fatal-infos` clean.
  Conformance unchanged: 364 divergences, 18 render failures.
- Found (correction): the macOS goldens from step 4 had the stretched
  `\vec` and off-center accent bug that `55e52e7` fixes. My review "by
  eye" missed it at full-sheet scale. After the merge, I compared the
  accent goldens at 4× zoom: `\vec` is one short arrow and `\hat`,
  `\tilde` and the others sit over their letter. Review goldens zoomed in,
  one at a time.
- Found: origin's `\textcolor` encoder still wrote the alpha channel; the
  merge keeps the fix from this branch.
- Next: push (owner). Then the Parser port, as in the previous entry.

## 2026-10-29 — Phase 1 follow-up — top-level line breaks render
- Done: `parseExpression` splits its result at each `CrNode` (`\\`,
  `\newline`, `\cr` outside an array) into rows of an
  `EquationArrayNode`. `\\[1ex]` sets the row spacing. As in KaTeX, a
  `\\` in display mode with strict `error` does nothing. A trailing
  break makes no empty row. Test: `test/line_break_test.dart` with a
  golden, reviewed at 3× zoom.
- Numbers: render failures 18 → 5. Divergences unchanged (364).
- Found (divergence, not tracked by the corpus): the rows are centered
  on each other. KaTeX left-aligns lines in inline mode. The corpus
  checks only that the case renders, not the layout.
- Left: `\rule{999em}{999em}` (overflow in the test view only),
  `\begin{matrix}\end{matrix}` (RangeError), two RenderResetDimension
  constraint failures (`\binom` in scripts, `\left\{\rule..\right.`),
  missing font metrics for nested `\textit\textbf` in `\text`.
- Next: the Parser port, as planned.

## 2026-10-29 — step 16 — Parser and defineFunction
- Done: `e73cc45`. Parser.ts and defineFunction.ts headers are
  `@ v0.19.1`. New: `test/parser_test.dart`,
  `test/katex_conformance/function_flags_test.dart`.
- Arguments: macro arguments through `scanArgument`, parsed to EOF
  (#2085). Dart handlers pull their arguments, and some fetch a token
  first, so each argument reader gives a fetched token back to the gullet
  (`_returnFetchedToken`). KaTeX handlers get their arguments before they
  run and need no such step.
- Flags: `allowedInArgument` replaces `greediness` (#2134). `generate` now
  also writes `test/katex_conformance/functions.json` and the Dart file
  `lib/src/parser/tex/katex_function_flags.dart`. `functions` applies
  those flags to every name that KaTeX defines (D9). Side effects:
  `\rule`, `\sout` and `\underline` work in text; text accents work in
  math with a `mathVsTextAccents` strict report; the TeX encoder no
  longer picks a text accent (`\=`) for a math accent (`\overline`).
- `\relax`: a function that returns `InternalNode`; the parser drops
  it. The MacroExpander divergence from the previous entry is closed.
- Numbers: divergences 364 → 352.
  Fixed: alpha colors (3), `\sout`/`\rule` in text (5), `\kern2\relax em`,
  `\mathop \int`, `\frac\bar\bar`, a `\displaystyle` array. No golden
  changed.
- Found: the port first added 4 divergences. `a\\ [b]` and `\\ [c]` in
  arrays: KaTeX reads a `\\` size only if `[` follows at once (cr.ts
  checks `gullet.future()` before `parseSizeGroup`, which skips spaces).
  `\'echec` in math: KaTeX reports it through `strict`. Both fixed.
- Found (pre-existing bug, fixed): Dart operator nodes take the next
  atom as their operand (`\sin x`). A `\\` became the operand of `\sin`
  and failed at build time. `parseOperand` now skips line breaks, infix
  commands and `\relax`.
- Found: `katex_spec_test.dart` had `#fA6f` as a bad color. KaTeX v0.19.1
  accepts it (#4090) and uses `#fA6f1`. Updated.
- Dart divergence (kept): unknown color names are an error. KaTeX passes
  any name to CSS. No corpus case has one.
- Remaining `not-ported` causes, most first: `\def` 28, `\smash` 27,
  starred environments 17, `\gdef` 15, `\mathllap` 11, strict unicode 10,
  `\@binrel` 9, `\mathreflectbox` 8, `\pmb` 7, `\mapsfrom` 7, `\let` 6.
- Next: `src/functions/def.ts` (`\def`, `\gdef`, `\edef`, `\xdef`,
  `\let`, `\global`, `\long`, `\futurelet`: about 56 cases). Then
  `lap.ts`/`smash.ts`, then `src/macros.ts`.

## 2026-10-29 — step 16 — def.ts, \tag, smash.ts, lap.ts
- Done: `0d90805` def.ts (`\def`, `\gdef`, `\edef`, `\xdef`, `\let`,
  `\futurelet`, `\global`, `\long`) and the parseTree `\tag` check.
  Next commit: `\smash`, `\mathllap`/`rlap`/`clap`, `\llap`/`rlap`/`clap`
  with new `SmashNode` and `LapNode` (public in ast.dart) and encoders.
- Numbers: divergences 352 → 297 → 247. Render failures unchanged (5).
- Found: with `\gdef` working, `\tag{hi}x+y` in inline mode parsed: the
  `\tag` macros already did `\gdef\df@tag`, but the parseTree check was
  missing. Ported it with `subparse`.
- Dart divergence: `\tag` puts the tag after the equation with a
  `\qquad`. KaTeX puts it at the right edge of the display.
- Divergence (explained in divergences.json): the exponential `\def` case
  that ends in `x⁺` needs `src/unicodeSupOrSub.ts`.
- Found: my first `\futurelet` test was wrong, not the port.
- Found: the image viewer returned a cached image for a rewritten file.
  Write each review image to a new file name.
- Next: environments (`align`, `CD`, starred matrices: 17+ cases), then
  `src/macros.ts` (`\@binrel`, `\mathreflectbox`, `\pmb`, `\mapsfrom`).

## 2026-10-29 — step 16 — Groups 1 and 2 (macros, symbols, fixes, AMS environments)
- Done, in four commits: throwOnError and formatUnsupportedCmd; macros,
  symbols and small functions; AMS environments with one shared array
  loop (`parseArrayBody`) and cr.ts; the remaining small fixes.
- Numbers: divergences 247 -> 92. Render failures 5 -> 2. No existing
  golden changed. New goldens (reviewed zoomed): `ams_environments`
  (`=` signs aligned at the same x, measured), `katex_v0_19_1_misc`.
- Found (corpus): it did not record `throwOnError`, and it recorded a
  KaTeX warning as "accepted", although the KaTeX test setup stops the
  parse at the warning. Both fixed in the hook. Case ids changed once.
- Found (Dart bugs): U+FE0F was a macro for `\textregistered`; the
  color table key was "magenta (synonym of fuchsia)"; ResetDimension
  ignored its parent's constraints; an empty matrix and `\substack{}`
  crashed; nested text fonts failed for missing metrics.
- Changed behavior: `\not{ab}` parses (KaTeX does). This reverses an
  assertion in `not_overlay_test.dart` from `297dbb9`.
- Dart divergences (kept, documented in code): no automatic equation
  numbers in align/gather/equation; a `\tag` follows its row after a
  `\qquad`; accented letters render composed.
- Left (Group 3, 34 cases): `CD`, `\vcenter`, `\phase`, `\angl`,
  `\overbracket`/`\underbracket`, `\overgroup`, `\underlinesegment`,
  `\mathsfit`; one `unicodeSupOrSub.ts` case.
