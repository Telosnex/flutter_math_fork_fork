import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Golden images are compared only on macOS (ADR 001 D10). Font
/// rasterization differs between platforms, and the images in test/golden
/// were made on macOS. On other platforms, the test still checks that the
/// expression parses, builds, and lays out. Not in browsers: dart:io's
/// Platform throws there.
final bool compareGoldens = !kIsWeb && Platform.isMacOS;

/// Renders [expression] and compares it with a golden image.
///
/// The default image path is `golden/<slug of description>_<hash>.png`.
void testTexToMatchGoldenFile(
  String description,
  String expression, {
  String? location,
  double scale = 1,
  TexParserSettings settings = const TexParserSettings(),
}) {
  testWidgets(description, (WidgetTester tester) async {
    // Web tests draw the square glyphs of the test font, much wider than
    // KaTeX's: a wider view, so the long expressions do not overflow.
    tester.view.physicalSize = Size((kIsWeb ? 2000 : 500) * scale, 300 * scale);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      _mathApp(
        Math.tex(
          expression,
          key: key,
          settings: settings,
          options: MathOptions(
            style: MathStyle.display,
            fontSize: scale * MathOptions.defaultFontSize,
          ),
          onErrorFallback: (e) => throw e,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (compareGoldens) {
      await expectLater(
        find.byKey(key),
        matchesGoldenFile(
          location ?? 'golden/${goldenFileName(description, expression)}',
        ),
      );
    }
  });
}

/// A file name for a golden image that does not change between runs.
String goldenFileName(String description, String expression) {
  final slug = description
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final shortSlug = slug.length > 60 ? slug.substring(0, 60) : slug;
  return '${shortSlug}_${_fnv1a32('$description\u0000$expression')}.png';
}

String _fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(input)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

Widget _mathApp(Widget math) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: math,
            ),
          ),
        ),
      ),
    );

/// Renders [expression] and fails on any parse, build, or layout error.
void testTexToRender(
  String description,
  String expression, [
  Future<void> Function(WidgetTester)? callback,
]) {
  testWidgets(description, (WidgetTester tester) async {
    await tester.pumpWidget(
      _mathApp(
        Math.tex(
          expression,
          options: MathOptions(
            fontSize: MathOptions.defaultFontSize,
            style: MathStyle.display,
          ),
          onErrorFallback: (e) => throw e,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (callback != null) {
      await callback(tester);
    }
  });
}

/// Renders [expression1] and [expression2] under [settings] and requires
/// identical pixels. A parse error in either expression fails the test.
/// Skipped on the web: no toImage there in tests.
void testTexToRenderLike(
  String description,
  String expression1,
  String expression2, [
  TexParserSettings settings = strictSettings,
]) {
  testWidgets(description, (WidgetTester tester) async {
    final image1 = await _renderToPixels(tester, expression1, settings);
    final image2 = await _renderToPixels(tester, expression2, settings);
    expect(
      (image1.width, image1.height),
      (image2.width, image2.height),
      reason: 'Size of "$expression1" differs from size of "$expression2".',
    );
    expect(
      image1.pixels,
      orderedEquals(image2.pixels),
      reason: 'Pixels of "$expression1" differ from pixels of '
          '"$expression2".',
    );
  }, skip: kIsWeb);
}

Future<({int width, int height, Uint8List pixels})> _renderToPixels(
  WidgetTester tester,
  String expression,
  TexParserSettings settings,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    _mathApp(
      RepaintBoundary(
        key: key,
        child: Math.tex(
          expression,
          settings: settings,
          options: MathOptions(
            fontSize: MathOptions.defaultFontSize,
            style: MathStyle.display,
          ),
          onErrorFallback: (e) => throw e,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(key),
  );
  if (boundary.size.isEmpty) {
    return (
      width: boundary.size.width.round(),
      height: boundary.size.height.round(),
      pixels: Uint8List(0),
    );
  }
  final result = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData();
      return (
        width: image.width,
        height: image.height,
        pixels: bytes!.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
    }
  });
  return result!;
}

const strictSettings = TexParserSettings(strict: Strict.error);
const nonstrictSettings = TexParserSettings(strict: Strict.ignore);

EquationRowNode getParsed(String expr,
        [TexParserSettings settings = const TexParserSettings()]) =>
    TexParser(expr, settings).parse();

String prettyPrintJson(Map<String, Object> a) =>
    JsonEncoder.withIndent('| ').convert(a);

ToParse toParse([TexParserSettings settings = strictSettings]) =>
    ToParse(settings);

class ToParse extends Matcher {
  final TexParserSettings settings;

  ToParse(this.settings);

  @override
  Description describe(Description description) =>
      description.add('a TeX string that parses with the given settings');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map<dynamic, dynamic> matchState, bool verbose) {
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
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    try {
      if (item is String) {
        // ignore: unused_local_variable
        final res = TexParser(item, settings).parse();
        // print(prettyPrintJson(res.toJson()));
        return true;
      }
      return false;
    } on ParseException catch (_) {
      return false;
    }
  }
}

ToNotParse toNotParse([TexParserSettings settings = strictSettings]) =>
    ToNotParse(settings);

class ToNotParse extends Matcher {
  final TexParserSettings settings;

  ToNotParse(this.settings);

  @override
  Description describe(Description description) =>
      description.add('a TeX string with parse errors');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map<dynamic, dynamic> matchState, bool verbose) {
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
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
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

final toBuild = ToBuild();

final toBuildStrict = ToBuild(settings: strictSettings);

class ToBuild extends Matcher {
  final MathOptions options;
  final TexParserSettings settings;

  ToBuild({
    MathOptions? options,
    this.settings = nonstrictSettings,
  }) : options = options ?? MathOptions.displayOptions;

  @override
  Description describe(Description description) =>
      description.add('a TeX string can be built into widgets');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map<dynamic, dynamic> matchState, bool verbose) {
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
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
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
