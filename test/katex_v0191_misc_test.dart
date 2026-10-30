// Small functions, macros and fixes from KaTeX v0.19.1: htmlmathml.ts,
// mclass.ts (\@binrel), reflectbox.ts, mathchoice.ts, pmb.ts, hbox.ts,
// text.ts (\emph), font.ts (\mathnormal), accent.ts (\c, \textcircled),
// char.ts, macros.ts and symbols.ts.
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork_fork/ast.dart';
import 'package:flutter_math_fork_fork/flutter_math.dart';
import 'package:flutter_math_fork_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper.dart';
import 'load_fonts.dart';

const _default = TexParserSettings();

EquationRowNode parse(String tex, [TexParserSettings s = _default]) =>
    TexParser(tex, s).parse();

Matcher get fails => throwsA(isA<ParseException>());

Future<Size> mathSize(WidgetTester tester, String tex) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: Math.tex(tex, key: key, onErrorFallback: (e) => throw e),
    ),
  ));
  return tester.getSize(find.byKey(key));
}

void main() {
  setUpAll(loadKaTeXFonts);

  group('parses as KaTeX does', () {
    for (final tex in [
      r'L\@binrel=xR',
      r'\mapsfrom',
      r'a \mapsfrom b',
      r'\minuso',
      r'\pmb{\mu}',
      r'\reflectbox{abc}',
      r'\mathchoice{D}{T}{S}{SS}',
      r'\hbox{x}',
      r'\text{\emph{a \emph{b}}}',
      r'\mathnormal{x+1}',
      r'\Set{x | x<\frac12}',
      r'\set{x|x<5}',
      r'\Braket{\phi | A | \psi}',
      r'\copyright \textregistered',
      r'\text{© ®}',
      r'\text{\c c \aa \AA}',
      r'\varlimsup \injlim \varprojlim',
      r'\coloneq \Coloneqq \colonsim',
      r'\S \P \origof \imageof',
      r'\text{eV·nm} \text{a \vdots b}',
      r'\mathstrut \underbar{X} \dddot x',
      r'\bigl{|}',
      r'\operatorname{sn}\limits_{b>c}',
      r'\textcolor{magenta}{x}',
      r'\not{abc}',
      r'x \hspace*{1em} y',
      r'\sum_{\substack{}} x',
      '\u{1D56C}\u{1D586}',
    ]) {
      test(tex, () => expect(() => parse(tex), returnsNormally));
    }
  });

  group('rejects as KaTeX does', () {
    for (final tex in [
      r'\hbox{\frac a b}',
      r'\@char{\text{2}}',
      r'\char"110000',
      r'\raisebox5pt{text}',
      r'\begin{alignedat}{\text{2}}a&b\end{alignedat}',
      r'hello \cr world',
    ]) {
      test(tex, () => expect(() => parse(tex), fails));
    }
    test(r'\sout in math with strict error', () {
      expect(
        () => parse(r'\sout{x}', const TexParserSettings(strict: Strict.error)),
        fails,
      );
    });
  });

  test('strict error accepts accented and CJK text (KaTeX unicodeSymbols)', () {
    const strict = TexParserSettings(strict: Strict.error);
    expect(() => parse('\\text{é試ÀÿՀ}', strict), returnsNormally);
  });

  test(r'throwOnError false shows an undefined command in red', () {
    final node = parse(r'\foo', const TexParserSettings(throwOnError: false))
        .children
        .single as StyleNode;
    expect(node.optionsDiff.color, const Color(0xffcc0000));
    expect(node.children.map((c) => (c as SymbolNode).symbol).join(), r'\foo');
  });

  test(r'\@binrel takes the class of its first argument', () {
    // Wrapped in a group: the root row of a single row is that row.
    AtomType? type(String tex) =>
        (parse('a{$tex}').children.last as EquationRowNode).overrideType;
    expect(type(r'\@binrel+x'), AtomType.bin);
    expect(type(r'\@binrel=x'), AtomType.rel);
    expect(type(r'\@binrel{x}x'), AtomType.ord);
  });

  test(r'\emph toggles italic', () {
    const upright = FontOptions();
    final italic =
        upright.mergeWith(const PartialFontOptions(toggleShape: true));
    expect(italic.fontShape, FontStyle.italic);
    expect(
      italic.mergeWith(const PartialFontOptions(toggleShape: true)).fontShape,
      FontStyle.normal,
    );
  });

  testWidgets(r'\mathchoice picks by style', (tester) async {
    final display =
        await mathSize(tester, r'\displaystyle\mathchoice{WWW}{T}{S}{SS}');
    final text =
        await mathSize(tester, r'\textstyle\mathchoice{WWW}{T}{S}{SS}');
    expect(display.width, greaterThan(text.width));
  });

  testWidgets(r'\reflectbox and \pmb keep the width', (tester) async {
    final plain = await mathSize(tester, 'abc');
    expect(
        (await mathSize(tester, r'\mathreflectbox{abc}')).width, plain.width);
    expect((await mathSize(tester, r'\pmb{abc}')).width, plain.width);
  });

  testTexToMatchGoldenFile(
    'katex v0.19.1 misc',
    r'\pmb{\mu}\mu \; \mathreflectbox{abc} \; a\mapsfrom b \; '
        r'\text{\textcircled{c} © ®} \; \Set{x | x<1} \; \not{abc}',
  );
}
