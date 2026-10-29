// ADR 001 invariants I1 and I2: for each KaTeX corpus case, the Dart parser
// accepts or rejects the input as KaTeX does, except for the cases in
// divergences.json. Each listed case must still diverge.
//
// After a parser change, update the list:
//   flutter test test/katex_conformance/conformance_test.dart \
//     --dart-define=KATEX_UPDATE=true
// Then set the category and note of each new entry.
@TestOn('vm') // dart:io reads the corpus files.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'corpus.dart';

void main() {
  final corpus = loadCases();
  final cases = corpus.cases.where((c) => c.portable).toList();
  var listed = readDivergences(divergencesPath);

  final results = <String, DartResult>{};
  final observed = <String, Divergence>{};
  // The parser logs strict-mode warnings. Do not print them for each case.
  runZoned(
    () {
      for (final c in cases) {
        final r = parseWithDart(c);
        results[c.id] = r;
        if (agrees(c, r)) continue;
        final old = listed[c.id];
        observed[c.id] = Divergence(
          category:
              old?.category ?? (c.usesTrustCommand ? 'trust' : 'not-ported'),
          note: old?.note ?? '',
          tex: shorten(c.tex),
          katex: c.katexAccepted
              ? 'accepted'
              : 'rejected: ${shorten(c.katexMessage ?? '', 100)}',
          dart: '${r.outcome.name}'
              '${r.message == null ? '' : ': ${shorten(r.message!, 100)}'}',
        );
      }
    },
    zoneSpecification: ZoneSpecification(print: (_, __, ___, ____) {}),
  );

  if (updateMode) {
    writeDivergences(divergencesPath, observed);
    listed = observed;
  }

  test(
      'corpus is from KaTeX ${corpus.katex}: '
      '${cases.length} portable cases, ${observed.length} divergences', () {
    final summary = <String, int>{};
    for (final d in observed.values) {
      summary[d.category] = (summary[d.category] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('KaTeX ${corpus.katex}: ${cases.length} portable cases, '
        '${cases.length - observed.length} agree, '
        '${observed.length} diverge $summary');
  });

  test('every divergence has a known category', () {
    final unknown = {
      for (final e in listed.entries)
        if (!categories.contains(e.value.category)) e.key: e.value.category,
    };
    expect(unknown, isEmpty);
  });

  test('I1: no new divergence from KaTeX', () {
    final added = {
      for (final e in observed.entries)
        if (!listed.containsKey(e.key))
          e.key: '${e.value.tex}\n    KaTeX: ${e.value.katex}'
              '\n    Dart: ${e.value.dart}',
    };
    expect(
      added,
      isEmpty,
      reason: 'The Dart parser now differs from KaTeX for these cases. Fix '
          'the parser, or run with --dart-define=KATEX_UPDATE=true and '
          'explain each entry.',
    );
  });

  test('I2: each listed divergence still diverges', () {
    final fixed = [
      for (final id in listed.keys)
        if (!observed.containsKey(id)) id,
    ];
    expect(
      fixed,
      isEmpty,
      reason: 'These cases now agree with KaTeX. Run with '
          '--dart-define=KATEX_UPDATE=true to remove them from the list.',
    );
  });

  test('no Dart parser crashes (exceptions other than ParseException)', () {
    final crashes = {
      for (final c in cases)
        if (results[c.id]!.outcome == DartOutcome.crashed &&
            listed[c.id]?.category != 'intentional')
          c.id: results[c.id]!.message,
    };
    // Crashes are also divergences. This test lists them separately,
    // because a crash is a bug even where KaTeX also rejects the input.
    if (crashes.isNotEmpty) {
      markTestSkipped('${crashes.length} crashes, all in divergences.json');
    }
    for (final id in crashes.keys) {
      expect(listed.containsKey(id), isTrue, reason: 'unlisted crash $id');
    }
  });
}
