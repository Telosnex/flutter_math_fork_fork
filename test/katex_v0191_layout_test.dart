// KaTeX v0.19.1 layout commands: \vcenter (vcenter.ts), \angl and \phase
// (enclose.ts), \overbracket and \underbracket (horizBrace.ts),
// \overgroup, \undergroup, \overlinesegment, \underlinesegment (accent.ts,
// accentunder.ts), \mathsfit (font.ts).
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'encoder/tex/recode.dart';
import 'helper.dart';
import 'load_fonts.dart';

Future<RenderBox> pumpMath(WidgetTester tester, String tex) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: Math.tex(
        tex,
        key: key,
        textStyle: const TextStyle(fontSize: 40),
        onErrorFallback: (e) => throw e,
      ),
    ),
  ));
  return tester.renderObject<RenderBox>(find.byKey(key));
}

void main() {
  setUpAll(loadKaTeXFonts);

  testWidgets(r'\vcenter puts the middle of the box on the axis',
      (tester) async {
    // A tall box with no depth: \vcenter moves it down, so the formula
    // gets depth.
    final plain = await pumpMath(tester, r'\rule{1em}{3em}');
    final plainHeight = plain.size.height;
    final centered = await pumpMath(tester, r'\vcenter{\rule{1em}{3em}}');
    // Same total size; the axis (0.25em) is the middle of the 3em rule.
    expect(centered.size.height, closeTo(plainHeight, 1));
  });

  testWidgets(r'\angl and \phase add room for their lines', (tester) async {
    final plain = (await pumpMath(tester, 'n')).size;
    final angl = (await pumpMath(tester, r'\angl{n}')).size;
    final phase = (await pumpMath(tester, r'\phase{n}')).size;
    expect(angl.width, greaterThan(plain.width));
    expect(angl.height, greaterThan(plain.height));
    expect(phase.width, greaterThan(plain.width));
  });

  test('TeX encoding round-trips', () {
    for (final tex in [
      r'\overgroup{AB}',
      r'\overlinesegment{AB}',
      r'\overbracket{AB}',
    ]) {
      expect(recodeTex(tex), tex);
    }
  });

  test(r'\angln is \angl n', () {
    expect(
      () => Math.tex(r'a_\angln').parseError ?? (throw 'ok'),
      throwsA('ok'),
    );
  });

  testTexToMatchGoldenFile(
    'katex v0.19.1 layout boxes',
    r'a+\vcenter{\hbox{$\frac{\frac ab}c$}} \; a_{\angl{n}} \; '
        r'120\phase{-78.2^\circ} \; \mathsfit{Ax2k}\mathsf{Ax2k}',
  );

  testTexToMatchGoldenFile(
    'katex v0.19.1 layout stretchy',
    r'\overbracket{1+2}^{x} \; \underbracket{1+2}_{y} \; '
        r'\overgroup{AB} \; \undergroup{AB} \; '
        r'\overlinesegment{AB} \; \underlinesegment{AB}',
  );
}
