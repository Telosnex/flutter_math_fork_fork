import 'package:flutter/material.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/encoder/tex/encoder.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork/src/render/layout/custom_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'load_fonts.dart';

void main() {
  setUpAll(loadKaTeXFonts);

  test('negated leadsto preserves relation type and round-trips as TeX', () {
    final row =
        TexParser(r's \not\leadsto T', const TexParserSettings()).parse();
    final arrow = row.children[1] as SymbolNode;
    expect(arrow.symbol, '\u21DD\u0338');
    expect(arrow.atomType, AtomType.rel);
    final encoded = row.encodeTeX();
    final decoded = TexParser(encoded, const TexParserSettings()).parse();
    expect((decoded.children[1] as SymbolNode).symbol, arrow.symbol);
  });

  test('mapped negations retain existing symbols', () {
    final row =
        TexParser(r'\not=\not\to\not\in', const TexParserSettings()).parse();
    expect(row.children.cast<SymbolNode>().map((node) => node.symbol),
        ['\u2260', '\u219B', '\u2209']);
  });

  test('single-symbol braces work; incomplete and multi-symbol args still fail',
      () {
    expect(Math.tex(r'\not{\leadsto}').parseError, isNull);
    expect(Math.tex(r'\not').parseError, isNotNull);
    expect(Math.tex(r'\not{ab}').parseError, isNotNull);
  });

  testWidgets('overlay is centered and does not widen the relation',
      (tester) async {
    final negated = Math.tex(r's \not\leadsto T');
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: Center(child: negated))));
    final width = tester.getSize(find.byWidget(negated)).width;
    final arrow = find.byWidgetPredicate((widget) =>
        widget is RichText && widget.text.toPlainText() == '\u21DD');
    final slash = find.byWidgetPredicate((widget) =>
        widget is RichText && widget.text.toPlainText() == '\uE020');
    expect(
        tester.getCenter(slash).dx, closeTo(tester.getCenter(arrow).dx, 0.01));
    final box = tester.renderObject<RenderCustomLayout<int>>(
      find.ancestor(of: slash, matching: find.byType(CustomLayout<int>)).first,
    );
    final baseline = box.delegate.computeDistanceToActualBaseline(
        TextBaseline.alphabetic, box.childrenTable);
    expect(baseline, isNotNull);
    expect(box.getDryLayout(const BoxConstraints()), box.size);
    expect(box.getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic),
        closeTo(baseline!, 0.01));

    final plain = Math.tex(r's \leadsto T');
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: Center(child: plain))));
    expect(tester.getSize(find.byWidget(plain)).width, closeTo(width, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final expression in [
    r's \not\leadsto T',
    r'A \not\mapsto B',
    r'x \not\propto y'
  ]) {
    for (final style in [MathStyle.display, MathStyle.text, MathStyle.script]) {
      testWidgets('$expression renders with a visible overlay in $style',
          (tester) async {
        final math = Math.tex(expression, mathStyle: style);
        expect(math.parseError, isNull);
        await tester
            .pumpWidget(MaterialApp(home: Scaffold(body: Center(child: math))));
        expect(tester.takeException(), isNull);
        final slash = find.byWidgetPredicate((widget) =>
            widget is RichText && widget.text.toPlainText() == '\uE020');
        expect(slash, findsOneWidget,
            reason: 'Negation must be painted, not silently dropped');
        final slashBox = tester.getRect(slash);
        expect(slashBox.width, greaterThan(0));
        expect(slashBox.height, greaterThan(0));
      });
    }
  }
}
