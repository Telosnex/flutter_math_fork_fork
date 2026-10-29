import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The goldens were made on Windows, and are compared there only. Not in
/// browsers: dart:io's Platform throws there.
final bool _compareGoldens = !kIsWeb && Platform.isWindows;

void testTexToMatchGoldenFile(
  String description,
  String expression, {
  String? location,
  double scale = 1,
  String? skip,
}) {
  testWidgets(description, (WidgetTester tester) async {
    // Web tests draw the square glyphs of the test font, much wider than
    // KaTeX's: a wider view, so the long expressions do not overflow.
    tester.view.physicalSize = Size((kIsWeb ? 2000 : 500) * scale, 300 * scale);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Math.tex(
                  expression,
                  key: key,
                  options: MathOptions(
                    style: MathStyle.display,
                    fontSize: scale * MathOptions.defaultFontSize,
                  ),
                  onErrorFallback: (error) => throw error,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (_compareGoldens) {
      await expectLater(find.byKey(key),
          matchesGoldenFile(location ?? 'golden/${description.hashCode}.png'));
    }
  }, skip: skip);
}

void testTexToRender(
  String description,
  String expression, [
  Future<void> Function(WidgetTester)? callback,
]) {
  testWidgets(description, (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Math.tex(
                  expression,
                  options: MathOptions(
                    fontSize: MathOptions.defaultFontSize,
                    style: MathStyle.display,
                  ),
                  onErrorFallback: (error) => throw error,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (callback != null) {
      await callback(tester);
    }
  });
}

/// Renders [expression1] and [expression2] and expects the same pixels.
/// Compared in memory, on every platform but the web (no toImage there in
/// tests). This used goldens under golden/temp/, which were stale.
void testTexToRenderLike(
    String description, String expression1, String expression2,
    [TexParserSettings settings = strictSettings]) {
  testWidgets(description, (WidgetTester tester) async {
    Future<(int, int, Uint8List)> render(String expression) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Math.tex(
                    expression,
                    options: MathOptions(
                      fontSize: MathOptions.defaultFontSize,
                      style: MathStyle.display,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData();
        final result = (image.width, image.height, bytes!.buffer.asUint8List());
        image.dispose();
        return result;
      }))!;
    }

    final first = await render(expression1);
    final second = await render(expression2);
    expect((second.$1, second.$2), (first.$1, first.$2),
        reason: 'image sizes of $expression2 and $expression1');
    expect(second.$3, first.$3, reason: '$expression2 renders as $expression1');
  }, skip: kIsWeb);
}

const strictSettings = TexParserSettings(strict: Strict.error);
const nonstrictSettings = TexParserSettings(strict: Strict.ignore);

EquationRowNode getParsed(String expr,
        [TexParserSettings settings = const TexParserSettings()]) =>
    TexParser(expr, settings).parse();

String prettyPrintJson(Map<String, Object> a) =>
    JsonEncoder.withIndent('| ').convert(a);

_ToParse toParse([TexParserSettings settings = strictSettings]) =>
    _ToParse(settings);

class _ToParse extends Matcher {
  final TexParserSettings settings;

  _ToParse(this.settings);

  @override
  Description describe(Description description) =>
      description.add('a TeX string can be parsed with default settings');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    try {
      if (item is String) {
        TexParser(item, settings).parse();
        return super
            .describeMismatch(item, mismatchDescription, matchState, verbose);
      }
      return mismatchDescription.add('input is not a string');
    } on ParseException catch (e) {
      return mismatchDescription.add(e.message);
    } on Object catch (e) {
      return mismatchDescription.add(e.toString());
    }
  }

  @override
  bool matches(dynamic item, Map matchState) {
    try {
      if (item is String) {
        // ignore: unused_local_variable
        final res = TexParser(item, const TexParserSettings()).parse();
        // print(prettyPrintJson(res.toJson()));
        return true;
      }
      return false;
    } on ParseException catch (_) {
      return false;
    }
  }
}

_ToNotParse toNotParse([TexParserSettings settings = strictSettings]) =>
    _ToNotParse(settings);

class _ToNotParse extends Matcher {
  final TexParserSettings settings;

  _ToNotParse(this.settings);

  @override
  Description describe(Description description) =>
      description.add('a TeX string with parse errors');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    try {
      if (item is String) {
        // ignore: unused_local_variable
        final res = TexParser(item, settings).parse();
        return super
            .describeMismatch(item, mismatchDescription, matchState, verbose);
        // return mismatchDescription.add(prettyPrintJson(res.toJson()));
      }
      return mismatchDescription.add('input is not a string');
    } on ParseException catch (_) {
      return super
          .describeMismatch(item, mismatchDescription, matchState, verbose);
    }
  }

  @override
  bool matches(dynamic item, Map matchState) {
    try {
      if (item is String) {
        // ignore: unused_local_variable
        final res = TexParser(item, settings).parse();
        // print(prettyPrintJson(res.toJson()));
        return false;
      }
      return false;
    } on ParseException catch (_) {
      return true;
    }
  }
}

final toBuild = _ToBuild();

final toBuildStrict = _ToBuild(settings: strictSettings);

class _ToBuild extends Matcher {
  final MathOptions options;
  final TexParserSettings settings;

  _ToBuild({
    MathOptions? options,
    this.settings = nonstrictSettings,
  }) : this.options = options ?? MathOptions.displayOptions;

  @override
  Description describe(Description description) =>
      description.add('a TeX string can be built into widgets');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    try {
      if (item is String) {
        final ast = SyntaxTree(
          greenRoot: TexParser(item, settings).parse(),
        );
        ast.buildWidget(options);
        return super
            .describeMismatch(item, mismatchDescription, matchState, verbose);
      }
      return mismatchDescription.add('input is not a string');
    } on ParseException catch (e) {
      return mismatchDescription.add(e.message);
    } on Object catch (e) {
      return mismatchDescription.add(e.toString());
    }
  }

  @override
  bool matches(dynamic item, Map matchState) {
    try {
      if (item is String) {
        final ast = SyntaxTree(
          greenRoot: TexParser(item, settings).parse(),
        );
        ast.buildWidget(options);
        return true;
      }
      return false;
    } on ParseException catch (_) {
      return false;
    }
  }
}
