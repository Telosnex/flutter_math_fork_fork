import 'dart:convert';
import 'dart:io';

import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void testTexToMatchGoldenFile(
  String description,
  String expression, {
  String? location,
  double scale = 1,
}) {
  testWidgets(description, (WidgetTester tester) async {
    tester.view.physicalSize = Size(500 * scale, 300 * scale);
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
                  onErrorFallback: (e) => throw e,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (Platform.isWindows) {
      // Android-specific code
      await expectLater(find.byKey(key),
          matchesGoldenFile(location ?? 'golden/${description.hashCode}.png'));
    }
  });
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
                  onErrorFallback: (e) => throw e,
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

void testTexToRenderLike(
    String description, String expression1, String expression2,
    [TexParserSettings settings = strictSettings]) {
  testWidgets(description, (WidgetTester tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Math.tex(
                  expression1,
                  key: key,
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
    if (Platform.isWindows) {
      // Android-specific code
      await expectLater(
          find.byKey(key),
          matchesGoldenFile(
              'golden/temp/${(description + expression1 + expression2).hashCode}.png'));
    }

    final key2 = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Math.tex(
                  expression2,
                  key: key2,
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
    if (Platform.isWindows) {
      // Android-specific code
      await expectLater(
          find.byKey(key2),
          matchesGoldenFile(
              'golden/temp/${(description + expression1 + expression2).hashCode}.png'));
    }
  });
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
      description.add('a TeX string can be parsed with default settings');

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
