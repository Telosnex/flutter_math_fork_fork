// Unicode (sub|super)script characters: KaTeX v0.19.1 src/Parser.ts with
// src/unicodeSupOrSub.ts.
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'encoder/tex/recode.dart';
import 'helper.dart';
import 'load_fonts.dart';

MultiscriptsNode scripts(String tex) =>
    TexParser(tex, const TexParserSettings()).parse().children.single
        as MultiscriptsNode;

String text(EquationRowNode? row) =>
    row!.children.map((c) => (c as SymbolNode).symbol).join();

void main() {
  setUpAll(loadKaTeXFonts);

  test('superscripts', () {
    final node = scripts('x²³');
    expect(text(node.sup), '23');
    expect(node.sub, isNull);
  });

  test('subscripts', () {
    expect(text(scripts('x₁₀').sub), '10');
  });

  test('a run ends where sub changes to sup', () {
    final node = scripts('x₁²');
    expect(text(node.sub), '1');
    expect(text(node.sup), '2');
  });

  test('letters and operators', () {
    expect(text(scripts('eⁱᵖ').sup), 'ip');
    expect(text(scripts('x⁺').sup), '+');
  });

  test('encodes as the TeX form', () {
    expect(recodeTex('x²'), 'x^2');
  });

  test(r'goes through macros: \def+ applies to ⁺', () {
    final node = scripts(r'\def+{y}x⁺');
    expect(text(node.sup), 'y');
  });

  testTexToRenderLike('x²₁ renders like x^2_1', 'x²₁', 'x^2_1');
}
