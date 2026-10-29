// Shared code for the KaTeX conformance tests. ADR 001, sections 3 to 5.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/macros.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';

const casesPath = 'test/katex_conformance/cases.json';
const divergencesPath = 'test/katex_conformance/divergences.json';
const renderFailuresPath = 'test/katex_conformance/render_failures.json';

/// `flutter test test/katex_conformance --dart-define=KATEX_UPDATE=true`
/// rewrites the divergence files from the current Dart results.
const updateMode = bool.fromEnvironment('KATEX_UPDATE');

const categories = {
  'not-ported',
  'setting',
  'trust',
  'intentional',
  'render-error',
};

class KatexCase {
  KatexCase(Map<String, dynamic> json)
      : id = json['id'] as String,
        tex = json['tex'] as String,
        settings = json['settings'] as Map<String, dynamic>,
        portable = json['portable'] as bool,
        sources = (json['sources'] as List<dynamic>).cast<String>(),
        katexAccepted = (json['katex'] as Map<String, dynamic>)['ok'] as bool,
        katexMessage =
            (json['katex'] as Map<String, dynamic>)['message'] as String?;

  final String id;
  final String tex;
  final Map<String, dynamic> settings;
  final bool portable;
  final List<String> sources;
  final bool katexAccepted;
  final String? katexMessage;

  /// The case uses a command that KaTeX allows only with `trust`. ADR 001
  /// NG3: the Dart parser does not support these commands.
  bool get usesTrustCommand => _trustCommand.hasMatch(tex);

  static final _trustCommand =
      RegExp(r'\\(href|url|includegraphics|htmlClass|htmlId|htmlStyle|'
          r'htmlData)(?![A-Za-z])');

  TexParserSettings toDartSettings() {
    final macros = (settings['macros'] as Map<String, dynamic>).map(
      (key, value) =>
          MapEntry(key, MacroDefinition.fromString(value as String)),
    );
    return TexParserSettings(
      displayMode: settings['displayMode'] as bool,
      strict: _strict(settings['strict']),
      macros: macros,
      maxExpand: (settings['maxExpand'] as num).toInt(),
      globalGroup: settings['globalGroup'] as bool,
      colorIsTextColor: settings['colorIsTextColor'] as bool,
    );
  }

  static Strict _strict(Object? value) => switch (value) {
        true || 'error' => Strict.error,
        false || 'ignore' => Strict.ignore,
        'warn' => Strict.warn,
        _ => throw ArgumentError('strict: $value'),
      };
}

({String katex, List<KatexCase> cases}) loadCases() {
  final json =
      jsonDecode(File(casesPath).readAsStringSync()) as Map<String, dynamic>;
  return (
    katex: json['katex'] as String,
    cases: (json['cases'] as List<dynamic>)
        .map((c) => KatexCase(c as Map<String, dynamic>))
        .toList(),
  );
}

enum DartOutcome { accepted, rejected, crashed }

class DartResult {
  DartResult(this.outcome, [this.message]);
  final DartOutcome outcome;
  final String? message;
  EquationRowNode? tree;
}

DartResult parseWithDart(KatexCase c) {
  try {
    final tree = TexParser(c.tex, c.toDartSettings()).parse();
    return DartResult(DartOutcome.accepted)..tree = tree;
  } on ParseException catch (e) {
    return DartResult(DartOutcome.rejected, e.rawMessage);
  } on Object catch (e) {
    return DartResult(DartOutcome.crashed, '${e.runtimeType}: $e');
  }
}

/// The Dart result and the KaTeX result are the same.
bool agrees(KatexCase c, DartResult r) =>
    r.outcome != DartOutcome.crashed &&
    (r.outcome == DartOutcome.accepted) == c.katexAccepted;

// ---------------------------------------------------------------------------
// Divergence files

class Divergence {
  Divergence({
    required this.category,
    required this.note,
    required this.tex,
    required this.katex,
    required this.dart,
  });

  factory Divergence.fromJson(Map<String, dynamic> json) => Divergence(
        category: json['category'] as String,
        note: json['note'] as String? ?? '',
        tex: json['tex'] as String? ?? '',
        katex: json['katex'] as String? ?? '',
        dart: json['dart'] as String? ?? '',
      );

  /// People edit [category] and [note]. The update mode keeps them.
  final String category;
  final String note;

  /// The update mode writes these fields for people to read.
  final String tex;
  final String katex;
  final String dart;

  Map<String, dynamic> toJson() => {
        'category': category,
        'note': note,
        'tex': tex,
        'katex': katex,
        'dart': dart,
      };
}

Map<String, Divergence> readDivergences(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return json.map(
    (id, value) =>
        MapEntry(id, Divergence.fromJson(value as Map<String, dynamic>)),
  );
}

/// One entry for each line, keys sorted, so that a diff shows one line for
/// each changed case.
void writeDivergences(String path, Map<String, Divergence> divergences) {
  final ids = divergences.keys.toList()..sort();
  final buffer = StringBuffer('{\n');
  for (var i = 0; i < ids.length; i++) {
    final comma = i == ids.length - 1 ? '' : ',';
    buffer.writeln('${jsonEncode(ids[i])}: '
        '${jsonEncode(divergences[ids[i]]!.toJson())}$comma');
  }
  buffer.writeln('}');
  File(path).writeAsStringSync(buffer.toString());
}

String shorten(String s, [int max = 160]) {
  final oneLine = s.replaceAll('\n', r'\n');
  return oneLine.length <= max ? oneLine : '${oneLine.substring(0, max)}…';
}
