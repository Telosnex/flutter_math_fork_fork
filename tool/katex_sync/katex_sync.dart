// KaTeX sync tool. ADR 001, section 5.
//
// Usage:
//   dart run tool/katex_sync/katex_sync.dart generate --katex <checkout>
//   dart run tool/katex_sync/katex_sync.dart status --katex <checkout>
//
// generate: runs the KaTeX jest suite at the pinned tag with
// record_parse_calls.js and writes test/katex_conformance/cases.json.
// Needs Node.js and pnpm. Only this command writes cases.json.
//
// status: lists the KaTeX commits to each ported file after the revision in
// its `// katex-sync:` header.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _versionFile = 'tool/katex_sync/katex_version';
const _hookFile = 'tool/katex_sync/record_parse_calls.js';
const _casesFile = 'test/katex_conformance/cases.json';

// The hook is copied into the KaTeX checkout, so that babel-jest finds
// KaTeX's @babel/runtime. The tool deletes the copy after the run.
const _hookCopyName = 'test/zz_katex_sync_record_parse_calls.js';

Future<void> main(List<String> args) async {
  if (args.isEmpty) _usage();
  final command = args.first;
  final katexIndex = args.indexOf('--katex');
  if (katexIndex < 0 || katexIndex + 1 >= args.length) _usage();
  final katexDir = Directory(args[katexIndex + 1]).absolute;
  if (!File('pubspec.yaml').existsSync() || !File(_versionFile).existsSync()) {
    _fail('Run this tool from the flutter_math_fork_fork root.');
  }
  switch (command) {
    case 'generate':
      await _generate(katexDir);
    case 'status':
      await _status(katexDir);
    default:
      _usage();
  }
}

Never _usage() {
  stderr.writeln('Usage: dart run tool/katex_sync/katex_sync.dart '
      '(generate|status) --katex <KaTeX checkout>');
  exit(64);
}

Never _fail(String message) {
  stderr.writeln('katex_sync: $message');
  exit(1);
}

String get pinnedTag => File(_versionFile).readAsStringSync().trim();

Future<String> _run(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  Map<String, String>? environment,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if (result.exitCode != 0) {
    _fail('$executable ${arguments.join(' ')} failed '
        '(exit ${result.exitCode}):\n${result.stdout}\n${result.stderr}');
  }
  return (result.stdout as String).trim();
}

Future<void> _checkPin(Directory katexDir) async {
  final tag = pinnedTag;
  final head =
      await _run('git', ['rev-parse', 'HEAD'], workingDirectory: katexDir.path);
  final tagCommit = await _run(
    'git',
    ['rev-parse', '$tag^{commit}'],
    workingDirectory: katexDir.path,
  );
  if (head != tagCommit) {
    _fail('KaTeX checkout is not at $tag. '
        'Run: git -C ${katexDir.path} checkout $tag');
  }
}

// ---------------------------------------------------------------------------
// generate

Future<void> _generate(Directory katexDir) async {
  await _checkPin(katexDir);
  final status = await _run(
    'git',
    ['status', '--porcelain', '--untracked-files=no'],
    workingDirectory: katexDir.path,
  );
  if (status.isNotEmpty) {
    _fail('KaTeX checkout has local changes:\n$status');
  }

  if (!Directory('${katexDir.path}/node_modules').existsSync()) {
    stdout.writeln('Installing KaTeX dependencies (pnpm install).');
    await _run(
      'pnpm',
      ['install', '--frozen-lockfile'],
      workingDirectory: katexDir.path,
      environment: {'COREPACK_ENABLE_STRICT': '0'},
    );
  }

  final packageJson = jsonDecode(
    File('${katexDir.path}/package.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final jestConfig = packageJson['jest'] as Map<String, dynamic>? ?? {};
  final setupFiles = [
    ...(jestConfig['setupFilesAfterEnv'] as List<dynamic>? ?? [])
        .cast<String>(),
    '<rootDir>/$_hookCopyName',
  ];

  final recordDir = Directory.systemTemp.createTempSync('katex_sync_');
  final hookCopy = File('${katexDir.path}/$_hookCopyName');
  File(_hookFile).copySync(hookCopy.path);
  try {
    stdout.writeln('Running the KaTeX jest suite at $pinnedTag.');
    await _run(
      'npx',
      ['jest', '--setupFilesAfterEnv', ...setupFiles],
      workingDirectory: katexDir.path,
      environment: {'KATEX_RECORD_DIR': recordDir.path},
    );
  } finally {
    if (hookCopy.existsSync()) hookCopy.deleteSync();
  }

  final records = <Map<String, dynamic>>[];
  final files = recordDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.jsonl'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) _fail('The hook wrote no records.');
  for (final file in files) {
    for (final line in file.readAsLinesSync()) {
      if (line.isEmpty) continue;
      records.add(jsonDecode(line) as Map<String, dynamic>);
    }
  }
  recordDir.deleteSync(recursive: true);

  final cases = buildCases(records);
  writeCases(cases);
  final accepted = cases.where((c) => c.katex['ok'] == true).length;
  final portable = cases.where((c) => c.portable).length;
  stdout.writeln('Wrote ${cases.length} cases to $_casesFile '
      '($accepted accepted, ${cases.length - accepted} rejected, '
      '$portable portable) from ${records.length} parse calls.');
}

class Case {
  Case({
    required this.id,
    required this.tex,
    required this.settings,
    required this.portable,
    required this.sources,
    required this.katex,
  });

  final String id;
  final String tex;
  final Map<String, dynamic> settings;
  final bool portable;
  final List<String> sources;
  final Map<String, dynamic> katex;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tex': tex,
        'settings': settings,
        'portable': portable,
        'sources': sources,
        'katex': katex,
      };
}

/// The result that KaTeX gave. The KaTeX test setup turns console.warn into
/// a thrown ConsoleWarning. Outside the tests, KaTeX accepts the input and
/// prints the warning, so the result is "accepted, with a warning".
Map<String, dynamic> normalizeResult(Map<String, dynamic> raw) {
  if (raw['ok'] == true) return {'ok': true};
  if (raw['kind'] == 'ConsoleWarning') {
    return {'ok': true, 'warning': raw['message']};
  }
  return {
    'ok': false,
    'kind': raw['kind'],
    'message': raw['message'],
    'position': raw['position'],
  };
}

String caseId(String tex, Map<String, dynamic> settings) {
  final canonical = canonicalJson({'settings': settings, 'tex': tex});
  return sha256.convert(utf8.encode(canonical)).toString().substring(0, 12);
}

/// JSON with map keys sorted at every level.
String canonicalJson(Object? value) => jsonEncode(_sortKeys(value));

Object? _sortKeys(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _sortKeys(value[k])};
  }
  if (value is List) return value.map(_sortKeys).toList();
  return value;
}

List<Case> buildCases(List<Map<String, dynamic>> records) {
  final byId = <String, List<Map<String, dynamic>>>{};
  for (final record in records) {
    final tex = record['tex'] as String;
    final settings = record['settings'] as Map<String, dynamic>;
    byId.putIfAbsent(caseId(tex, settings), () => []).add(record);
  }

  final cases = <Case>[];
  for (final entry in byId.entries) {
    final group = entry.value;
    final first = group.first;
    final portable = group.every((r) => r['portable'] == true);
    final results = {
      for (final r in group)
        canonicalJson(normalizeResult(r['katex'] as Map<String, dynamic>)),
    };
    if (portable && results.length > 1) {
      _fail('KaTeX gave different results for the same input and '
          'settings (${entry.key}): ${first['tex']}\n${results.join('\n')}');
    }
    // A non-portable case has function settings. Different functions give
    // different results. The conformance test skips these cases.
    final sources = {
      for (final r in group) '${r['file']}: ${r['source']}',
    }.toList()
      ..sort();
    cases.add(Case(
      id: entry.key,
      tex: first['tex'] as String,
      settings: _sortKeys(first['settings']) as Map<String, dynamic>,
      portable: portable,
      sources: sources,
      katex: normalizeResult(first['katex'] as Map<String, dynamic>),
    ));
  }
  cases.sort((a, b) => a.id.compareTo(b.id));
  return cases;
}

/// One case for each line, so that a diff shows one line for each case.
void writeCases(List<Case> cases) {
  final buffer = StringBuffer()
    ..writeln('{')
    ..writeln('"katex": ${jsonEncode(pinnedTag)},')
    ..writeln('"generator": "tool/katex_sync/katex_sync.dart generate",')
    ..writeln('"cases": [');
  for (var i = 0; i < cases.length; i++) {
    final comma = i == cases.length - 1 ? '' : ',';
    buffer.writeln('${canonicalJson(cases[i].toJson())}$comma');
  }
  buffer
    ..writeln(']')
    ..writeln('}');
  File(_casesFile)
    ..createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());
}

// ---------------------------------------------------------------------------
// status

final _headerPattern = RegExp(r'^// katex-sync: (\S+) @ (\S+)\s*$');

Future<void> _status(Directory katexDir) async {
  await _checkPin(katexDir);
  final headers = <({String dartFile, String katexPath, String revision})>[];
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in dartFiles) {
    for (final line in file.readAsLinesSync().take(40)) {
      final match = _headerPattern.firstMatch(line);
      if (match != null) {
        headers.add((
          dartFile: file.path,
          katexPath: match[1]!,
          revision: match[2]!,
        ));
      }
    }
  }
  if (headers.isEmpty) {
    stdout.writeln('No `// katex-sync:` headers found in lib/.');
    return;
  }

  final tag = pinnedTag;
  var behind = 0;
  for (final h in headers) {
    final exists = await Process.run(
      'git',
      ['cat-file', '-e', '$tag:${h.katexPath}'],
      workingDirectory: katexDir.path,
    );
    if (exists.exitCode != 0) {
      stdout.writeln('${h.dartFile}: ${h.katexPath} does not exist at $tag.');
      behind++;
      continue;
    }
    // KaTeX renamed src/*.js to src/*.ts. Follow the file history.
    final log = await _run(
      'git',
      [
        'log',
        '--no-merges',
        '--follow',
        '--format=%h %ad %s',
        '--date=short',
        '${h.revision}..$tag',
        '--',
        h.katexPath,
      ],
      workingDirectory: katexDir.path,
    );
    final commits = log.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (commits.isEmpty) continue;
    behind++;
    stdout.writeln('${h.dartFile} ← ${h.katexPath} @ ${h.revision}: '
        '${commits.length} commits');
    for (final c in commits) {
      stdout.writeln('    $c');
    }
  }
  stdout.writeln('${headers.length} headers, $behind behind $tag.');
}
