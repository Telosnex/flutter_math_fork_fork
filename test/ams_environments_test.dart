// AMS environments from KaTeX v0.19.1 src/environments/array.ts: align,
// align*, split, gather, gather*, gathered, alignat, alignat*, equation,
// equation*, and the starred matrices.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork_fork/ast.dart';
import 'package:flutter_math_fork_fork/flutter_math.dart';
import 'package:flutter_math_fork_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork_fork/src/render/layout/eqn_array.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper.dart';
import 'load_fonts.dart';

const display = TexParserSettings(displayMode: true);

GreenNode parseOne(String tex, [TexParserSettings settings = display]) =>
    TexParser(tex, settings).parse().children.single;

Matcher get fails => throwsA(isA<ParseException>());

void main() {
  setUpAll(loadKaTeXFonts);
  equationNumberTests();

  group('display mode only', () {
    for (final env in [
      'align',
      'align*',
      'split',
      'gather',
      'gather*',
      'equation',
      'equation*',
    ]) {
      test(env, () {
        final tex = '\\begin{$env}a\\end{$env}';
        expect(() => parseOne(tex), returnsNormally);
        expect(
          () => parseOne(tex, const TexParserSettings()),
          fails,
        );
      });
    }
    test('aligned and gathered work inline', () {
      for (final env in ['aligned', 'gathered']) {
        expect(
          () => parseOne(
            '\\begin{$env}a\\end{$env}',
            const TexParserSettings(),
          ),
          returnsNormally,
        );
      }
    });
  });

  test('align rows', () {
    final node =
        parseOne(r'\begin{align}a&=b\\c&=d\end{align}') as EquationArrayNode;
    expect(node.body, hasLength(2));
  });

  test('an empty single row is kept', () {
    final node = parseOne(r'\begin{gather}\end{gather}') as EquationArrayNode;
    expect(node.body, hasLength(1));
  });

  test('equation has one column', () {
    expect(() => parseOne(r'\begin{equation}a&b\end{equation}'), fails);
  });

  test('split has at most two columns', () {
    expect(() => parseOne(r'\begin{split}a&b&c\end{split}'), fails);
  });

  test('alignat checks its column count', () {
    expect(
      () => parseOne(r'\begin{alignat}{1}a&=b&c&=d\end{alignat}'),
      fails,
    );
    expect(() => parseOne(r'\begin{alignat}{x}a\end{alignat}'), fails);
  });

  test(r'\tag on a row', () {
    expect(
      () => parseOne(r'\begin{align}a&=b\tag{1}\\c&=d\notag\end{align}'),
      returnsNormally,
    );
  });

  test(r'\cr[x] is \\ then "[x]"', () {
    final matrix =
        parseOne(r'\begin{matrix}a\cr[c]&d\end{matrix}') as MatrixNode;
    expect(matrix.body, hasLength(2));
  });

  group('starred matrices', () {
    for (final (arg, align) in [
      ('', MatrixColumnAlign.center),
      ('[l]', MatrixColumnAlign.left),
      ('[r]', MatrixColumnAlign.right),
    ]) {
      test('matrix*$arg', () {
        final matrix = parseOne(
          '\\begin{matrix*}$arg a & -1 \\\\ -1 & d \\end{matrix*}',
        ) as MatrixNode;
        expect(matrix.columnAligns, [align, align]);
      });
    }
    test('bad alignment', () {
      expect(() => parseOne(r'\begin{matrix*}[x]a\end{matrix*}'), fails);
    });
  });

  testTexToMatchGoldenFile(
    'ams environments',
    r'\begin{align*}a&=b+c\\d+e&=f\end{align*}\quad'
        r'\begin{gather*}x=1\\y+z=22\end{gather*}\quad'
        r'\begin{pmatrix*}[r]1&-1\\-10&2\end{pmatrix*}',
    settings: display,
  );
}

String symbolsOf(GreenNode node) => node is SymbolNode
    ? node.symbol
    : node.children.map((c) => c == null ? '' : symbolsOf(c)).join();

// Counts measured with KaTeX v0.19.1 renderToString (".eqn-num" spans).
void equationNumberTests() {
  List<String?> tags(String tex) {
    final node = TexParser(tex, display).parse().children.single;
    final array = node is EquationArrayNode
        ? node
        : (node as EquationRowNode).children.single as EquationArrayNode;
    return [
      for (final tag in array.tags) tag == null ? null : symbolsOf(tag),
    ];
  }

  group('equation numbers', () {
    for (final (tex, expected) in [
      (r'\begin{align}a\\b\end{align}', ['(1)', '(2)']),
      // KaTeX keeps a numbered empty last row.
      (r'\begin{align}a\\b\\\end{align}', ['(1)', '(2)', '(3)']),
      (
        r'\begin{align}a\nonumber\\b\tag{x}\\c\end{align}',
        [null, '(x)', '(1)']
      ),
      (r'\begin{gather}\end{gather}', ['(1)']),
      (r'\begin{equation}x\end{equation}', ['(1)']),
      (r'\begin{align*}a\\b\end{align*}', <String?>[]),
      (r'\begin{aligned}a\\b\end{aligned}', <String?>[]),
      (
        r'\begin{gather}a\\b\end{gather}\begin{gather}c\end{gather}',
        ['(1)', '(2)']
      ),
    ]) {
      test(tex, () {
        if (tex.contains('end{gather}\\begin')) {
          // Two environments in one formula: numbers continue.
          final arrays = TexParser(tex, display)
              .parse()
              .children
              .whereType<EquationArrayNode>()
              .toList();
          expect(symbolsOf(arrays.last.tags.single!), '(3)');
          return;
        }
        expect(tags(tex), expected);
      });
    }
  });

  testWidgets('the numbers form one right-aligned column on the row baselines',
      (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Math.tex(
          r'\begin{align}a&=b+c+d\\x&=y\end{align}',
          settings: display,
          onErrorFallback: (e) => throw e,
        ),
      ),
    ));
    final eqn = tester.renderObject<RenderBox>(find.byType(EqnArray));
    final rows = <RenderBox>[];
    eqn.visitChildren((c) => rows.add(c as RenderBox));
    final row1 = rows[0], row2 = rows[1], tag1 = rows[2], tag2 = rows[3];
    double left(RenderBox b) => (b.parentData! as BoxParentData).offset.dx;
    // Read cached baselines after layout (Flutter allows it only then).
    double base(RenderBox b) {
      RenderObject.debugCheckingIntrinsics = true;
      try {
        return (b.parentData! as BoxParentData).offset.dy +
            b.getDistanceToBaseline(TextBaseline.alphabetic)!;
      } finally {
        RenderObject.debugCheckingIntrinsics = false;
      }
    }

    double right(RenderBox b) => left(b) + b.size.width;
    expect(right(tag1), right(tag2)); // right-aligned, as KaTeX
    expect(left(tag1), greaterThan(right(row1)));
    expect(base(tag1), closeTo(base(row1), 0.01));
    expect(base(tag2), closeTo(base(row2), 0.01));
  });

  testTexToMatchGoldenFile(
    'equation numbers',
    r'\begin{align}a&=b+c\\d+e&=f\nonumber\\g&=h\tag{*}\\i&=j\end{align}',
    settings: display,
  );
}
