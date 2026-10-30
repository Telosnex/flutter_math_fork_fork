// ADR 001 invariant I5: the API that cmark-gfm-widget and Telosnex use
// continues to compile and render. Copies the call sites from
// cmark-gfm-widget lib/src/render/{inline,block}_renderers.dart and
// lib/src/render/math_parser_settings.dart. Keep only public imports here.
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'load_fonts.dart';

Strict _strictFun(String errorCode, String errorMsg, Object? token) =>
    errorCode == 'unknownSymbol' ? Strict.error : Strict.warn;

const _settings = TexParserSettings(strictFun: _strictFun);

Widget _app(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(child: child),
      ),
    );

void main() {
  setUpAll(loadKaTeXFonts);

  for (final style in [MathStyle.text, MathStyle.display]) {
    testWidgets('Math.tex renders with $style', (tester) async {
      await tester.pumpWidget(
        _app(
          Math.tex(
            r'\frac{a}{b} + \sqrt{x}',
            mathStyle: style,
            textStyle: const TextStyle(fontSize: 16),
            settings: _settings,
            onErrorFallback: (error) => const Text('fallback'),
          ),
        ),
      );
      expect(find.byType(Math), findsOneWidget);
      expect(find.text('fallback'), findsNothing);
      expect(tester.getSize(find.byType(Math)).width, greaterThan(0));
    });
  }

  testWidgets('strictFun error goes to onErrorFallback', (tester) async {
    FlutterMathException? seen;
    await tester.pumpWidget(
      _app(
        Math.tex(
          'x 😀',
          settings: _settings,
          onErrorFallback: (error) {
            seen = error;
            return const Text('fallback');
          },
        ),
      ),
    );
    expect(find.text('fallback'), findsOneWidget);
    expect(seen, isA<ParseException>());
    // Like KaTeX, the parser reports UTF-16 code units: the first surrogate
    // of U+1F600 is 55357. cmark-gfm-widget parses this number.
    expect(seen!.message, contains('(55357)'));
  });
}
