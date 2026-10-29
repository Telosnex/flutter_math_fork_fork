# flutter_math_fork (Telosnex fork)

TeX math rendering in pure Dart and Flutter. The parser is a Dart port of
the [KaTeX](https://github.com/KaTeX/KaTeX) parser.

Lineage: [znjameswu/flutter_math](https://github.com/znjameswu/flutter_math)
→ [simpleclub-extended/flutter_math_fork](https://github.com/simpleclub-extended/flutter_math_fork)
→ this repository. The package name stays `flutter_math_fork`.

Status and plan: [ADR 001](doc/adr/001_modernize_and_sync_with_katex.md)
and [MODERNIZE_WORKLOG.md](MODERNIZE_WORKLOG.md). The parser matches
KaTeX from 2020 (commit `c2e5a289`). The ADR describes how it will sync
with current KaTeX.

## Samples

`x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}`

![Quadratic formula](doc/img/delta.png)

`i\hbar\frac{\partial}{\partial t}\Psi(\vec x,t) = -\frac{\hbar}{2m}\nabla^2\Psi(\vec x,t)+ V(\vec x)\Psi(\vec x,t)`

![Schrödinger equation](doc/img/schrodinger.png)

`\hat f(\xi) = \int_{-\infty}^\infty f(x)e^{- 2\pi i \xi x}\mathrm{d}x`

![Fourier transform](doc/img/fourier.png)

These images are golden test outputs (`test/render_sample_test.dart`).

## Install

```yaml
dependencies:
  flutter_math_fork:
    git:
      url: https://github.com/Telosnex/flutter_math_fork_fork.git
      ref: master
```

## Usage

```dart
import 'package:flutter_math_fork/flutter_math.dart';

// Display style (the default).
Math.tex(r'\frac a b', mathStyle: MathStyle.display)

// Inline style.
Math.tex(r'\frac a b', mathStyle: MathStyle.text)
```

The font size and color come from the ambient `DefaultTextStyle` and
`MediaQuery` text scaling. `textStyle` overrides them. `textStyle` also
changes the screen size of absolute units (cm, pt, in). To set those
separately, use `logicalPpi`.

```dart
Math.tex(r'\frac a b', textStyle: const TextStyle(fontSize: 42))
```

### Parser settings

`TexParserSettings` is a subset of the KaTeX settings: `strict`,
`strictFun`, `macros`, `maxExpand`, `colorIsTextColor`.

```dart
Math.tex(
  input,
  settings: const TexParserSettings(strict: Strict.ignore),
)
```

### Errors

`onErrorFallback` gets a `ParseException` or a `BuildException` and returns
the widget to show. It runs during `build`.

```dart
Math.tex(
  input,
  onErrorFallback: (error) => Text(input),
)
```

### Parse once, render many times

```dart
final ast = SyntaxTree(
  greenRoot: TexParser(r'\frac a b', const TexParserSettings()).parse(),
);
Math(ast: ast, mathStyle: MathStyle.text);
```

### Selection

This package has no selectable widget. To select math together with
surrounding text, put `Math` in a `SelectionArea` with a `Selectable`
render object that copies the TeX source. See `InlineMathSelectable` in
cmark-gfm-widget.

### Line breaking

`texBreak()` on a `Math` widget breaks the equation at TeX break points. See
[doc/line_breaking.md](doc/line_breaking.md).

## Development

```sh
flutter analyze
flutter test                 # goldens compare on macOS only
flutter test --update-goldens
```

Golden images are made on macOS. Review every changed image before you
commit it.

## Credits

[KaTeX](https://katex.org/), [MathJax](https://www.mathjax.org),
[Zefyr](https://github.com/memspace/zefyr), and
[CaTeX](https://github.com/simpleclub/CaTeX). Original author: James Wu
([znjameswu](https://github.com/znjameswu)).
