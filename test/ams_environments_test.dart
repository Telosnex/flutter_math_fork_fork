// AMS environments from KaTeX v0.19.1 src/environments/array.ts: align,
// align*, split, gather, gather*, gathered, alignat, alignat*, equation,
// equation*, and the starred matrices.
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helper.dart';
import 'load_fonts.dart';

const display = TexParserSettings(displayMode: true);

GreenNode parseOne(String tex, [TexParserSettings settings = display]) =>
    TexParser(tex, settings).parse().children.single;

Matcher get fails => throwsA(isA<ParseException>());

void main() {
  setUpAll(loadKaTeXFonts);

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
