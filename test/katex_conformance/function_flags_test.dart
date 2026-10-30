// The flags of each Dart FunctionSpec match the KaTeX function table. The
// flags come from katex_function_flags.dart; this test finds a stale copy
// of it (functions.json and the Dart file are written together). ADR 001 D9.
@TestOn('vm') // dart:io reads functions.json.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_math_fork_fork/src/parser/tex/functions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flags that differ from KaTeX on purpose. Name → reason.
const _intentional = <String, String>{};

void main() {
  final table = jsonDecode(
    File('test/katex_conformance/functions.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final katex = (table['functions'] as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();

  for (final flag in [
    'allowedInArgument',
    'primitive',
    'allowedInText',
    'allowedInMath',
    'infix',
  ]) {
    test('$flag matches KaTeX', () {
      final mismatches = <String>[];
      for (final name in katex.keys.toList()..sort()) {
        final spec = functions[name];
        if (spec == null || _intentional.containsKey(name)) continue;
        final dartValue = switch (flag) {
          'allowedInArgument' => spec.allowedInArgument,
          'primitive' => spec.primitive,
          'allowedInText' => spec.allowedInText,
          'allowedInMath' => spec.allowedInMath,
          _ => spec.infix,
        };
        if (dartValue != katex[name]![flag]) {
          mismatches.add('$name: Dart $dartValue, KaTeX ${katex[name]![flag]}');
        }
      }
      expect(mismatches, isEmpty);
    });
  }
}
