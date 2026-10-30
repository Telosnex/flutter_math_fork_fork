// \def, \gdef, \edef, \xdef, \let, \futurelet, \global, \long: KaTeX
// v0.19.1 src/functions/def.ts. Also \tag (KaTeX parseTree.ts).
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork_fork/ast.dart';
import 'package:flutter_math_fork_fork/flutter_math.dart';
import 'package:flutter_math_fork_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'load_fonts.dart';

const _settings = TexParserSettings();

List<GreenNode> parse(String tex, [TexParserSettings settings = _settings]) =>
    TexParser(tex, settings).parse().children;

/// The symbols of [tex], in order, ignoring structure.
String symbols(String tex, [TexParserSettings settings = _settings]) {
  final out = StringBuffer();
  void walk(GreenNode? node) {
    if (node == null) return;
    if (node is SymbolNode) out.write(node.symbol);
    node.children.forEach(walk);
  }

  parse(tex, settings).forEach(walk);
  return out.toString();
}

Matcher get fails => throwsA(isA<ParseException>());

void main() {
  setUpAll(loadKaTeXFonts);

  test(r'\def with arguments', () {
    expect(symbols(r'\def\f#1#2{#2#1}\f ab'), 'ba');
  });

  test(r'\def with delimited parameters', () {
    expect(symbols(r'\def\f#1.#2;{#2#1}\f xy.z;w'), 'zxyw');
  });

  test(r'\def with # before { (brace delimiter)', () {
    expect(symbols(r'\def\f#1#{[#1]}\f ab{c}'), '[ab]c');
  });

  test(r'\def is local to a group; \gdef and \global\def are not', () {
    expect(() => parse(r'{\def\x{1}}\x'), fails);
    expect(symbols(r'{\gdef\x{1}}\x'), '1');
    expect(symbols(r'{\global\def\x{2}}\x'), '2');
    expect(symbols(r'{\global\long\def\x{3}}\x'), '3');
  });

  test(r'\edef expands at definition time', () {
    expect(symbols(r'\def\a{1}\edef\b{\a}\def\a{2}\b\a'), '12');
  });

  test(r'\let copies the current meaning', () {
    expect(symbols(r'\def\a{1}\let\b=\a\def\a{2}\b\a'), '12');
    expect(symbols(r'\let\b= x\b'), 'x');
  });

  test(r'\let to a function keeps the function', () {
    expect(
      parse(r'\let\foo=\frac \def\frac{\relax} \foo12').single,
      isA<FracNode>(),
    );
  });

  test(r'\futurelet', () {
    // \a gets y, the token after x; x and y stay in the input.
    expect(symbols(r'\futurelet\a xy\a'), 'xyy');
  });

  test('errors', () {
    expect(() => parse(r'\def{x}'), fails);
    expect(() => parse(r'\def\f#2{x}'), fails);
    expect(() => parse(r'\def\f#1#3{x}'), fails);
    expect(() => parse(r'\def\f'), fails);
    expect(() => parse(r'\global x'), fails);
    expect(() => parse(r'\let{x'), fails);
  });

  test('maxExpand stops recursion', () {
    expect(() => parse(r'\def\x{\x}\x'), fails);
  });

  test('a macro does not outlive its parse', () {
    expect(symbols(r'\gdef\x{1}\x'), '1');
    expect(() => parse(r'\x'), fails);
  });

  group(r'\tag', () {
    const display = TexParserSettings(displayMode: true);
    test('needs display mode', () {
      expect(() => parse(r'\tag{1}x'), fails);
      expect(symbols(r'x\tag{1}', display), 'x(1)');
      expect(symbols(r'x\tag*{A}', display), 'xA');
    });
    test('twice is an error', () {
      expect(() => parse(r'\tag1\tag2 x', display), fails);
    });
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Math.tex(
          r'E = mc^2 \tag{1}',
          settings: display,
          onErrorFallback: (e) => throw e,
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
