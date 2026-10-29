# ADR 001 — Modernize the package and sync the parser with KaTeX
Status: ACCEPTED (2026-10-29)

## 1. Problem

This package parses TeX with a Dart port of the KaTeX parser. The port did
not change in a meaningful way after 2020. KaTeX continued development, and
the gap between the two is not known in detail.

Facts (2026-10-29, Flutter 3.47.1, KaTeX `v0.19.1`):

- The Dart parser matches KaTeX commit `c2e5a289` (2020-05-30). Evidence: the
  macro names in `lib/src/parser/tex/macros.dart` match KaTeX `src/macros.js`
  best between `v0.11.1` and `v0.12.0`. The Dart repo starts on 2020-06-05.
- Since `c2e5a289`, 255 KaTeX commits changed `src/` or `contrib/mhchem/`.
  KaTeX `v0.13.0` replaced `greediness` with `allowedInArgument` (#2134) and
  changed macro argument parsing (#2085). The Dart parser still uses
  `greediness`.
- KaTeX had these function files at `c2e5a289`, but the Dart port has no
  equivalent: `def`, `tag`, `lap`, `smash`, `mathchoice`, `verb`, `href`,
  `html`, `includegraphics`. KaTeX added `hbox`, `vcenter` (`v0.13.0`) and
  `pmb` (`v0.16.2`) later.
- The Dart parser ignores `TexParserSettings.displayMode`. KaTeX rejects
  `align` and `gather` outside display mode.
- The known gap lists are hand-written. One list came from 159 LLM-written
  probe expressions. Nobody can say if such a list is complete.
- `test/katex_spec_test.dart` has 385 tests. Somebody translated them by hand
  from KaTeX `test/katex-spec.js` (503 `it(` calls at `c2e5a289`, 645 at
  `v0.19.1`).
- Golden tests run only on Windows (`if (Platform.isWindows)` in
  `test/helper.dart`). On macOS and Linux they check only that no exception
  occurs. `testTexToRenderLike` compares nothing on any platform.
- `flutter test`: 410 tests pass, 8 fail. All 8 failures are in
  `SelectableMath` (`NoSuchMethodError: bringIntoView`).
- `flutter analyze`: 63 issues. There is no CI. `.travis.yml` refers to a
  service that this repo does not use.

The consequence: in Telosnex, valid LaTeX that KaTeX renders falls back to
raw text. Nobody can measure how often, or what to fix first.

## 2. Requirements

| ID | Requirement | Source | Hardness |
|----|-------------|--------|----------|
| R1 | For one pinned KaTeX release, the Dart parser accepts and rejects the same inputs as KaTeX, except for listed divergences. | founder | hard |
| R2 | The list of gaps comes from KaTeX data (its tests and its own results), not from hand-written or LLM-written lists. | founder | hard |
| R3 | A sync to a newer KaTeX release is a repeatable procedure. | founder | hard |
| R4 | The API that cmark-gfm-widget uses continues to work: `Math.tex`, `MathStyle`, `onErrorFallback`, `TexParserSettings(strictFun:)`. | platform | hard |
| R5 | Tests check rendering on macOS, the development platform, and in CI. | assumed | hard |
| R6 | `flutter analyze` reports zero issues on the current stable Flutter. | assumed | soft |
| R7 | At runtime, rendering is pure Dart and Flutter. No JavaScript and no web view. | assumed | hard |
| R8 | Node.js is permitted as a development tool. CI and package users do not need it. | assumed | soft |
| R9 | Long-term scripts are Dart. | founder | hard |

## 3. Decisions

```
D1: Pin one KaTeX release tag in tool/katex_sync/katex_version.
    Because: R1, R3
    Instead of: a commit on KaTeX main. KaTeX releases often, and a tag
    has a stable name and a matching npm package.

D2: The corpus is every call to KaTeX parseTree() that the KaTeX jest suite
    makes at the pinned tag. A jest setup file records the calls.
    Because: R2
    Instead of: regex extraction of string literals from katex-spec.ts. That
    misses computed inputs and settings. An LLM probe list fails R2.

D3: The expected result of each case is the result that KaTeX gave in the
    same jest run: success, or ParseError with its message and position.
    Because: R1, R2
    Instead of: the assertion in the KaTeX test (toParse, toNotParse). Many
    calls come from helpers that have no assertion of their own.

D4: The corpus is a generated file in the repo. Only the sync tool writes it.
    Because: R3, R5, R8
    Instead of: generation at test time. That puts Node and pnpm in CI.

D5: The conformance test compares the result only: accepted or rejected.
    Because: R1
    Instead of: a comparison of parse trees. Dart function handlers return
    GreenNode render nodes directly. No KaTeX-shaped tree exists to compare.
    See NG1.

D6: A divergence file lists each case where Dart and KaTeX disagree, with a
    category. The test fails on a new divergence. The test also fails when a
    listed case no longer diverges, so the list only gets shorter.
    Because: R1, R3
    Instead of: a minimum pass percentage. A percentage hides which case
    changed.

D7: Each Dart file that ports a KaTeX file has a header line that names the
    KaTeX file and the KaTeX revision it matches. The sync tool lists the
    KaTeX commits to that file since that revision.
    Because: R3
    Instead of: one global "synced to" version. Files sync at different
    times, and the first sync covers six years.

D8: The first sync ports in this order: lexer, namespace, macro expander,
    parser core, then macros and symbols, then environments, then functions.
    Because: R1. The v0.13.0 changes to argument parsing (#2085, #2134)
    change how every function gets its arguments.
    Instead of: functions first, by user demand. Each function port then
    depends on old argument rules and must change again later.

D9: When a KaTeX file is pure data (symbols, font metrics, Unicode tables),
    a Dart generator writes the Dart file from the KaTeX file.
    Because: R2, R3
    Instead of: edits by hand. Hand edits drift from KaTeX and cannot be
    checked.

D10: Golden images are made on macOS and compared on macOS only. Other
     platforms (Linux, Windows, web) still parse, build and lay out each
     golden expression. The Windows-only gate is removed.
     Because: R5
     Instead of: Windows goldens. Golden images differ between platforms,
     and development occurs on macOS.
     Comparison ignores a difference of at most 32 per color channel
     (test/flutter_test_config.dart). macOS 15 and the macOS 26 CI runner
     antialias glyph edges differently: at most 13 per channel, on at most
     61 pixels of an image. A moved glyph differs by up to 255.

D11: CI is the telosnex_ci_tools workflows. unit.yml (Ubuntu, each push
     and pull request): lint, dart format check, flutter analyze
     --fatal-infos, flutter test. integration.yml (push and nightly):
     flutter test on macOS ARM64 and Windows x64, and on Chrome with
     dart2js and dart2wasm. The macOS job compares the goldens (D10).
     Tests that need dart:io are @TestOn('vm').
     Because: R5, R6
     Instead of: a separate macOS-only workflow. The shared tools already
     pin Flutter and cover the web compilers.

D12: Remove SelectableMath and its support code from the package.
     Because: R4 (no consumer uses it), R6 (it causes most deprecation
     issues and all 8 test failures). cmark-gfm-widget already makes math
     selectable without it: `InlineMathSelectable`
     (lib/src/render/inline_math_selectable.dart) is a RenderProxyBox with
     Flutter's `Selectable` and `SelectionRegistrant`. It joins the
     enclosing SelectionArea, selects the expression as one unit, and
     copies the TeX source. The Math widget is under IgnorePointer.
     Instead of: a port to the current TextSelectionDelegate and
     contextMenuBuilder APIs. That costs much work for no consumer.

D13: Replace package:tuple with Dart records. Delete the unused
     canvas_kit_web.dart (dart:js).
     Because: R6
     Instead of: no change. tuple is discontinued and dart:js is deprecated.
```

## 4. Invariants

```
I1: For each corpus case that the divergence file does not list, the Dart
    parser and KaTeX give the same result (accepted or rejected).
    If violated: a parser change made Dart differ from KaTeX, and nobody
    knows.
    Pinned by: test/katex_conformance/conformance_test.dart

I2: Each case in the divergence file still diverges.
    If violated: the list overstates the gap, and fixed cases can regress
    with no test failure.
    Pinned by: test/katex_conformance/conformance_test.dart

I3: Each corpus case that the Dart parser accepts builds and lays out in a
    Math.tex widget with no exception, except for the cases in
    render_failures.json.
    If violated: the app shows a Flutter error box in place of math.
    Pinned by: test/katex_conformance/render_test.dart

I4: Two runs of the sync tool at the same pin give byte-identical files.
    If violated: regenerated files show false changes that hide real ones.
    Pinned by: manual check, needs Node (run generate two times, cmp)

I5: Code that uses the API in R4 compiles and renders.
    If violated: cmark-gfm-widget does not build.
    Pinned by: test/api_surface_test.dart

I6: flutter analyze reports zero issues.
    If violated: deprecated APIs accumulate until a Flutter release removes
    them.
    Pinned by: .github/workflows/ci.yml
```

## 5. Formats & names

Paths:

| Path | Content |
|------|---------|
| `tool/katex_sync/katex_version` | One line: a KaTeX tag, for example `v0.19.1`. |
| `tool/katex_sync/katex_sync.dart` | The sync tool. Commands: `generate --katex <checkout>`, `status --katex <checkout>`. |
| `tool/katex_sync/record_parse_calls.js` | Jest setup file. The only JavaScript in the repo. `generate` copies it into the KaTeX `test/` directory for the run, so that babel-jest finds KaTeX's `@babel/runtime`, and then deletes the copy. |
| `test/katex_conformance/cases.json` | Generated corpus. |
| `test/katex_conformance/functions.json` | Generated KaTeX function and environment table. |
| `lib/src/parser/tex/katex_function_flags.dart` | Generated from functions.json: KaTeX flags for each function (D9). |
| `test/katex_conformance/divergences.json` | Parse divergences (I1, I2). People edit `category` and `note`. |
| `test/katex_conformance/render_failures.json` | Accepted cases that do not render (I3). Same format and rules. |

`cases.json` is a JSON object with one case on each line:

```json
{
"katex": "v0.19.1",
"generator": "tool/katex_sync/katex_sync.dart generate",
"cases": [
{"id":"3f9a0c12be47","katex":{"ok":false,"kind":"ParseError","message":"...","position":0},"portable":true,"settings":{...},"sources":["katex-spec: ..."],"tex":"..."},
...
]
}
```

- `id`: the first 12 hex characters of SHA-256 of the canonical JSON of
  `{"settings", "tex"}`, with sorted keys. The id does not change between
  KaTeX versions if the input does not change. Cases are sorted by `id`.
- `settings`: `colorIsTextColor`, `displayMode`, `globalGroup`, `macros`,
  `maxExpand`, `strict`, `throwOnError`, `trust`, after KaTeX `Settings` fills in the
  defaults. Booleans are booleans (`ss_data.yaml` gives `display: 1`). A
  value that is a JavaScript function, and a macro that is not a string,
  is written as `"<function>"` or `"<object>"`.
- `portable`: false when a setting is a function or a non-string macro.
  The Dart tests cannot reproduce such a case and skip it.
- `sources`: `<KaTeX test file>: <test name>` for each call that gave this
  case. This field is for people to read. The tools do not use it.
- `katex`: `{"ok": true}`, or `{"ok": true, "warning": ...}`, or
  `{"ok": false, "kind", "message", "position"}`. The KaTeX test setup
  throws `ConsoleWarning` from `console.warn`. The hook then parses again
  with `console.warn` collecting messages, and records that result: what
  KaTeX does outside the tests. `message` is `ParseError.rawMessage`.
- Calls with a non-string input (KaTeX TypeError tests) are not recorded.

Divergence record (`divergences.json`, `render_failures.json`), a JSON
object with one entry on each line, keys sorted:

```json
{"3f9a0c12be47": {"category":"not-ported","note":"","tex":"...","katex":"accepted","dart":"rejected: ..."}}
```

`category` and `note` are for people. The update mode
(`--dart-define=KATEX_UPDATE=true`) keeps them and rewrites `tex`, `katex`
and `dart`. A new entry gets `trust` if the input uses `\href`, `\url`,
`\includegraphics` or `\html*`, `render-error` in `render_failures.json`,
and otherwise `not-ported`.

Categories: `not-ported`, `setting` (the Dart settings cannot express the
case), `trust` (NG3), `render-error` (I3), `intentional` (Dart differs on
purpose; `note` must give the reason).

Provenance header (D7), one line at the top of the Dart file:

```dart
// katex-sync: src/Parser.ts @ c2e5a289
```

The revision is a KaTeX tag or commit. The path is the KaTeX path at the
pinned tag. One Dart file can have more than one header line. `status`
follows renames (`src/*.js` to `src/*.ts`).

## 6. Non-goals

```
NG1: Parse-tree parity with KaTeX.
     Reopens when: the Dart parser has a parse layer that is separate from
     GreenNode, or result parity is reached and render bugs come from
     different tree shapes.

NG2: Pixel parity with KaTeX HTML output.
     Reopens when: the `not-ported` category is empty.

NG3: Trust features: \href, \url, \htmlClass, \includegraphics. MathML output.
     Reopens when: a consumer needs links or images in math.

NG4: Same error message text as KaTeX.
     Reopens when: a consumer shows parse error text to users.

NG5: Publication on pub.dev.
     Reopens when: a consumer outside Telosnex needs the package.

NG6: The amscd CD environment (KaTeX src/environments/cd.ts). It needs its
     own layout (stretched arrows, side labels) and covers only rectangular
     diagrams. Most real diagrams need tikz-cd (diagonal and curved arrows,
     arrow styles), which KaTeX does not support either. Corpus cases are
     `intentional`.
     Reopens when: models in Telosnex output \begin{CD} in practice.

NG6: Math editing and UnicodeMath input.
     Reopens when: a consumer needs them.
```

## 7. Risks

Ranked by irreversibility.

1. **The parser-core port changes output for input that renders correctly
   now.** The conformance test compares only accept or reject, so it does
   not see this change. Users see different math with no test failure.
   Mitigation: complete D10 (macOS goldens) before workplan step 13, and
   review every golden change.
2. **Parity makes Dart reject input that it accepts now.** KaTeX is stricter
   in some cases, for example `align` outside display mode. Users then see
   raw LaTeX where they saw math before. Mitigation: review each change
   from accepted to rejected. Keep the lenient result with category
   `intentional` when real chat output needs it.
3. **D12 removes public API.** Code outside Telosnex that uses
   SelectableMath stops compiling. Git history keeps the code, so the
   removal can be undone.
4. **The KaTeX jest suite does not test all commands.** The corpus cannot
   find a gap in a command that KaTeX does not test. Mitigation: add real
   LaTeX from Telosnex chats as a second corpus source. The KaTeX npm
   package at the pinned version gives the expected results for it.
5. **The jest recording hook depends on KaTeX internals** (the module path
   `src/parseTree`). A KaTeX change can break the hook. The cost is one
   hook update.

## 8. Workplan

Phase 0: make tests trustworthy. Complete this phase before parser changes
(risk 1).

1. Commit or revert the open edit to `analysis_options.yaml`. Add
   `example/ios/Flutter/ephemeral/` to `.gitignore`.
2. Replace the include in `analysis_options.yaml` with
   `package:flutter_lints/flutter.yaml`. Remove the `strong-mode` keys.
3. Fix all `flutter analyze` issues (I6).
4. Change `test/helper.dart`: run goldens on macOS, make
   `testTexToRenderLike` compare two renders, and make `toParse` use its
   `settings` argument. Regenerate all goldens. Examine each image.
5. Add the CI workflows (D11). Delete `.travis.yml` and
   `.github/workflows/publish.yml`.
6. Add `toString()` to `ParseException`.
7. Write `test/api_surface_test.dart` (I5).
8. Do D12 and D13. Get approval from the owner for D12 first.

Phase 1: build the conformance harness.

9. Check out KaTeX at the pinned tag. Run `pnpm install`. Write
   `record_parse_calls.js` and run the KaTeX jest suite with it. Record the
   number of cases in the worklog. If the hook cannot work, stop and amend
   D2.
10. Write `katex_sync.dart generate`. Run it two times and compare the
    output (I4).
11. Write `conformance_test.dart` with an `--update` mode that writes
    `divergences.json`. The default category is `not-ported`.
12. Write `render_test.dart` (I3).
13. Assign the `trust` and `setting` categories.
14. Add provenance headers (D7) to all Dart parser files. Use `c2e5a289`.
15. Write `katex_sync.dart status`.

Phase 2: the first sync, from `c2e5a289` to the pin.

16. Port the files in the D8 order. Use one commit for each KaTeX file.
    After each commit, run the goldens and the conformance test. Update the
    provenance header and the divergence file. Add a worklog entry.
17. Write the D9 generators for symbols, font metrics, and Unicode tables.
    Compare the generated files with the current Dart files and explain
    each difference.
18. Implement `displayMode` in the Dart parser.
19. Port the missing function files. Each new node type needs a GreenNode
    and a layout. KaTeX `buildHTML` shows the result, not the method.

Phase 3: later syncs. Do these steps for each new KaTeX release.

20. Write the new tag to `katex_version`. Run `generate`. Read the
    `cases.json` diff.
21. Run `status`. Port the listed KaTeX commits.
22. Update `divergences.json` and the worklog.

──────── non-normative ────────

## A. Alternatives & notes

- **Use the KaTeX npm package as the only source of expected results.**
  `npm pack katex@0.19.1` gives `dist/katex.js`. `katex.__parse(tex, settings)`
  returns the parse tree or throws `ParseError`, and needs no build. This
  works for an input list, but it gives no inputs. The jest recording (D2)
  gives inputs and results in one run. The npm package remains useful for
  risk 4 and for one-off questions.
- **Run KaTeX at runtime in a JS engine.** Rejected by R7.
- **Translate katex-spec.ts again by hand.** This is how
  `katex_spec_test.dart` came to exist. It fails R3: each KaTeX release
  needs a new translation.
- **KaTeX screenshotter images.** `test/screenshotter/images/` has KaTeX
  renders of the cases in `ss_data.yaml`. These cases are also in the
  corpus, because `screenshotter-spec.ts` parses each one. A future review
  sheet can put the Dart golden and the KaTeX image side by side (NG2).
- **KaTeX fonts.** Five commits changed `fonts/` after `c2e5a289`, for
  example #3206 (width of `\cong`). Copy the fonts in the same step as the
  font metrics (step 17).

## B. Revision history

- 2026-10-29: First draft.
- 2026-10-29: D12 cites the selection code in cmark-gfm-widget.
- 2026-10-29: D10: golden channel tolerance.
- 2026-10-29: NG6 (CD environment).
- 2026-10-29: Section 5: throwOnError in settings; warning results are
  re-parsed; functions.json and katex_function_flags.dart.
- 2026-10-29: D10 and D11 match the CI merged from origin/master
  (telosnex_ci_tools); macOS goldens kept.
- 2026-10-29: Accepted. Section 5 matches the implementation: `portable`,
  warning results, `render_failures.json`, category `render-error`.
