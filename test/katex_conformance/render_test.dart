// ADR 001 invariant I3: each corpus case that the Dart parser accepts
// builds and lays out in a Math widget with no exception. Known failures
// are in render_failures.json, with the same update rule as
// divergences.json:
//   flutter test test/katex_conformance/render_test.dart \
//     --dart-define=KATEX_UPDATE=true
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import '../load_fonts.dart';
import 'corpus.dart';

void main() {
  setUpAll(loadKaTeXFonts);

  testWidgets('I3: accepted corpus cases build and lay out', (tester) async {
    final corpus = loadCases();
    var listed = readDivergences(renderFailuresPath);
    final observed = <String, Divergence>{};
    var rendered = 0;

    for (final c in corpus.cases.where((c) => c.portable)) {
      final result = runZoned(
        () => parseWithDart(c),
        zoneSpecification:
            ZoneSpecification(print: (_, __, ___, ____) {}),
      );
      final tree = result.tree;
      if (tree == null) continue;
      rendered++;

      String? failure;
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        failure ??= details.exceptionAsString();
      };
      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Math(
                ast: SyntaxTree(greenRoot: tree),
                mathStyle: c.settings['displayMode'] == true
                    ? MathStyle.display
                    : MathStyle.text,
                textStyle: const TextStyle(fontSize: 20),
                onErrorFallback: (e) => throw e,
              ),
            ),
          ),
        );
      } on Object catch (e) {
        failure ??= '$e';
      } finally {
        FlutterError.onError = oldOnError;
      }
      final pending = tester.takeException();
      if (pending != null) failure ??= '$pending';

      if (failure != null) {
        final old = listed[c.id];
        observed[c.id] = Divergence(
          category: old?.category ?? 'render-error',
          note: old?.note ?? '',
          tex: shorten(c.tex),
          katex: c.katexAccepted ? 'accepted' : 'rejected',
          dart: 'parsed, render failed: ${shorten(failure!, 120)}',
        );
      }
    }
    await tester.pumpWidget(const SizedBox());

    if (updateMode) {
      writeDivergences(renderFailuresPath, observed);
      listed = observed;
    }

    // ignore: avoid_print
    print('Rendered $rendered accepted cases, ${observed.length} failed.');

    final added = [
      for (final id in observed.keys)
        if (!listed.containsKey(id)) '$id ${observed[id]!.tex}\n'
            '    ${observed[id]!.dart}',
    ];
    final fixed = [
      for (final id in listed.keys)
        if (!observed.containsKey(id)) id,
    ];
    expect(added, isEmpty, reason: 'New render failures.');
    expect(
      fixed,
      isEmpty,
      reason: 'These cases render now. Run with '
          '--dart-define=KATEX_UPDATE=true to remove them from the list.',
    );
  });
}
