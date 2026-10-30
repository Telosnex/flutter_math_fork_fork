// \smash (KaTeX src/functions/smash.ts) and \mathllap, \mathrlap,
// \mathclap, \llap, \rlap, \clap (src/functions/lap.ts).
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork_fork/ast.dart';
import 'package:flutter_math_fork_fork/flutter_math.dart';
import 'package:flutter_math_fork_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'encoder/tex/recode.dart';
import 'helper.dart';
import 'load_fonts.dart';

GreenNode parseOne(String tex) =>
    TexParser(tex, const TexParserSettings()).parse().children.single;

Future<Size> mathSize(WidgetTester tester, String tex) async {
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
  return tester.getSize(find.byKey(key));
}

void main() {
  setUpAll(loadKaTeXFonts);

  group(r'\smash', () {
    for (final (tex, height, depth) in [
      (r'\smash{y}', true, true),
      (r'\smash[t]{y}', true, false),
      (r'\smash[b]{y}', false, true),
      (r'\smash[tb]{y}', true, true),
      (r'\smash[x]{y}', false, false),
    ]) {
      test(tex, () {
        final node = parseOne(tex) as SmashNode;
        expect((node.smashHeight, node.smashDepth), (height, depth));
      });
    }

    testWidgets('removes height and depth from the layout', (tester) async {
      final plain = await mathSize(tester, r'\sqrt{\frac{a}{b}}');
      final smashed = await mathSize(tester, r'\smash{\sqrt{\frac{a}{b}}}');
      final top = await mathSize(tester, r'\smash[t]{\sqrt{\frac{a}{b}}}');
      expect(smashed.width, plain.width);
      expect(smashed.height, 0);
      expect(top.height, greaterThan(0));
      expect(top.height, lessThan(plain.height));
    });
  });

  group('lap', () {
    for (final (tex, alignment) in [
      (r'\mathllap{x}', LapAlignment.left),
      (r'\mathrlap{x}', LapAlignment.right),
      (r'\mathclap{x}', LapAlignment.center),
    ]) {
      test(tex, () {
        expect((parseOne(tex) as LapNode).alignment, alignment);
      });
    }

    test(r'\llap is \mathllap{\textrm{...}}', () {
      final node = parseOne(r'\llap{x}') as LapNode;
      expect(node.alignment, LapAlignment.left);
    });

    testWidgets('has zero width', (tester) async {
      final plain = await mathSize(tester, 'ab');
      final lapped = await mathSize(tester, r'a\mathrlap{wwww}b');
      expect(lapped.width, plain.width);
    });
  });

  test('TeX encoding round-trips', () {
    for (final tex in [
      r'\smash{x}',
      r'\smash[t]{x}',
      r'\smash[b]{x}',
      r'\mathllap{x}',
      r'\mathrlap{x}',
      r'\mathclap{x}',
    ]) {
      expect(recodeTex(tex), tex);
    }
  });

  testTexToMatchGoldenFile(
    'smash and lap',
    r'\left(\smash{\frac{a}{b}}\right) \; '
        r'\left(\smash[b]{\frac{a}{b}}\right) \; '
        r'\boxed{a\mathllap{/}} \; \boxed{a\mathrlap{/}} \; '
        r'\boxed{a\mathclap{/}} \; '
        // \rlap content must stay inside the widget to be in the image.
        r'\rlap{\text{note}}\qquad\qquad\quad y',
  );
}
