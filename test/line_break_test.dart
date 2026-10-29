// Top-level line breaks: KaTeX src/functions/cr.ts. `\\` and `\newline`
// outside an array break the line; they used to fail to build.
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper.dart';
import 'load_fonts.dart';

List<GreenNode> parse(String tex, [TexParserSettings? settings]) =>
    TexParser(tex, settings ?? const TexParserSettings()).parse().children;

void main() {
  setUpAll(loadKaTeXFonts);

  test(r'\\ makes one row per line', () {
    final nodes = parse(r'a \\ b + c \newline d');
    expect(nodes.single, isA<EquationArrayNode>());
    expect((nodes.single as EquationArrayNode).body, hasLength(3));
  });

  test(r'a trailing \\ makes no empty line', () {
    final nodes = parse(r'a \\ b \\');
    expect((nodes.single as EquationArrayNode).body, hasLength(2));
    expect(parse(r'a \\').single, isA<SymbolNode>());
  });

  test(r'\\[size] sets the row spacing', () {
    final array = parse(r'a \\[1ex] b').single as EquationArrayNode;
    expect(
      (array.rowSpacings.first.value, array.rowSpacings.first.unit),
      (1.0, Unit.ex),
    );
  });

  test(r'display mode with strict: \\ does nothing, as in LaTeX', () {
    final nodes = parse(
      r'a \\ b',
      const TexParserSettings(displayMode: true, strict: Strict.error),
    );
    expect(nodes.whereType<EquationArrayNode>(), isEmpty);
  });

  test(r'a line break inside a group', () {
    final nodes = parse(r'a + {b \\ c} + d');
    expect(nodes, hasLength(5));
  });

  testTexToMatchGoldenFile(
    'top-level line breaks',
    r'\frac{a}{b} = c \\[1ex] x + y \newline z',
  );
  testTexToRender(r'hello \\ world', r'\text{hello} \\ \text{world}');
}
