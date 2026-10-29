// katex-sync: src/environments/array.ts @ c2e5a289
// The MIT License (MIT)
//
// Copyright (c) 2013-2019 Khan Academy and other contributors
// Copyright (c) 2020 znjameswu <znjameswu@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../../../ast/nodes/left_right.dart';
import '../../../ast/nodes/matrix.dart';
import '../../../ast/nodes/style.dart';
import '../../../ast/nodes/symbol.dart';
import '../../../ast/options.dart';
import '../../../ast/size.dart';
import '../../../ast/style.dart';
import '../../../ast/syntax_tree.dart';
import '../define_environment.dart';
import '../macros.dart';
import '../parse_error.dart';
import '../parser.dart';
import '../token.dart';

const arrayEntries = {
  [
    'array',
    'darray',
  ]: EnvSpec(
    numArgs: 1,
    handler: _arrayHandler,
  ),
  [
    'matrix',
    'pmatrix',
    'bmatrix',
    'Bmatrix',
    'vmatrix',
    'Vmatrix',
    'matrix*',
    'pmatrix*',
    'bmatrix*',
    'Bmatrix*',
    'vmatrix*',
    'Vmatrix*',
  ]: EnvSpec(
    numArgs: 0,
    handler: _matrixHandler,
  ),
  ['smallmatrix']: EnvSpec(numArgs: 0, handler: _smallMatrixHandler),
  ['subarray']: EnvSpec(numArgs: 1, handler: _subArrayHandler),
};

enum ColSeparationType {
  align,
  alignat,
  small,
}

List<MatrixSeparatorStyle> getHLines(TexParser parser) {
  // Return an array. The array length = number of hlines.
  // Each element in the array tells if the line is dashed.
  final hlineInfo = <MatrixSeparatorStyle>[];
  parser.consumeSpaces();
  var next = parser.fetch().text;
  if (next == '\\relax') {
    // \relax is an artifact of the \cr macro
    parser.consume();
    parser.consumeSpaces();
    next = parser.fetch().text;
  }
  while (next == '\\hline' || next == '\\hdashline') {
    parser.consume();
    hlineInfo.add(next == '\\hdashline'
        ? MatrixSeparatorStyle.dashed
        : MatrixSeparatorStyle.solid);
    parser.consumeSpaces();
    next = parser.fetch().text;
  }
  return hlineInfo;
}

/// The rows of an array, a matrix or an AMS environment. KaTeX: the body
/// loop of parseArray (src/environments/array.ts).
class ArrayBody {
  ArrayBody({
    required this.body,
    required this.rowGaps,
    required this.hLines,
    required this.tags,
    required this.arrayStretch,
  });

  final List<List<EquationRowNode>> body;
  final List<Measurement> rowGaps;
  final List<MatrixSeparatorStyle> hLines;

  /// For each row, a manual tag (`\tag`), or null. Null if the
  /// environment takes no tags. Dart has no automatic equation numbers.
  final List<List<GreenNode>?>? tags;
  final double arrayStretch;
}

/// Parses rows delimited by `\\` and columns delimited by `&`.
///
/// [autoTag]: null for no tags; false for manual tags only; true for
/// automatic numbering (amsmath `align`, `gather`, `equation`). Dart keeps
/// the `\@eqnsw` bookkeeping but shows only manual tags.
ArrayBody parseArrayBody(
  TexParser parser, {
  double? arrayStretch,
  MathStyle? style,
  bool? autoTag,
  bool singleRow = false,
  bool emptySingleRow = false,
  int? maxNumCols,
  bool strictColumns = false,
}) {
  final gullet = parser.macroExpander;
  gullet.beginGroup();
  if (!singleRow) {
    // \cr is equivalent to \\ without the optional size argument
    gullet.macros.set('\\cr', MacroDefinition.fromString('\\\\\\relax'));
  }

  // Get current arraystretch if it's not set by the environment
  if (arrayStretch == null) {
    final stretch = gullet.expandMacroAsText('\\arraystretch');
    if (stretch == null) {
      // Default \arraystretch from lttab.dtx
      arrayStretch = 1.0;
    } else {
      arrayStretch = double.tryParse(stretch);
      if (arrayStretch == null || arrayStretch <= 0) {
        throw ParseException('Invalid \\arraystretch: $stretch');
      }
    }
  }

  // Start group for first cell
  gullet.beginGroup();

  var row = <EquationRowNode>[];
  final body = [row];
  final rowGaps = <Measurement>[];
  final hLinesBeforeRow = <MatrixSeparatorStyle>[];
  final tags = autoTag != null ? <List<GreenNode>?>[] : null;
  // Per row: an automatic number (true), not shown in Dart.
  var autoNumbered = false;

  // amsmath uses \global\@eqnswtrue and \global\@eqnswfalse to represent
  // whether this row should have an equation number. Simulate this with
  // a \@eqnsw macro set to 1 or 0.
  void beginRow() {
    if (autoTag == true) {
      gullet.macros
          .set('\\@eqnsw', MacroDefinition.fromString('1'), global: true);
    }
  }

  void endRow() {
    if (tags == null) return;
    if (gullet.macros.get('\\df@tag') != null) {
      tags.add(parser.subparse([Token('\\df@tag')]));
      gullet.macros.set('\\df@tag', null, global: true);
      autoNumbered = false;
    } else {
      tags.add(null);
      autoNumbered =
          autoTag == true && gullet.expandMacroAsText('\\@eqnsw') == '1';
    }
  }

  beginRow();

  // Test for \hline at the top of the array.
  hLinesBeforeRow
      .add(getHLines(parser).lastOrNull ?? MatrixSeparatorStyle.none);

  while (true) {
    // Parse each cell in its own group (namespace)
    final cellBody = parser.parseExpression(
      breakOnInfix: false,
      breakOnTokenText: singleRow ? '\\end' : '\\\\',
    );
    gullet.endGroup();
    gullet.beginGroup();

    final cell = style == null
        ? cellBody.wrapWithEquationRow()
        : StyleNode(
            children: cellBody,
            optionsDiff: OptionsDiff(style: style),
          ).wrapWithEquationRow();
    row.add(cell);

    final next = parser.fetch().text;
    if (next == '&') {
      if (maxNumCols != null && row.length == maxNumCols) {
        if (singleRow || strictColumns) {
          // {equation} or {split}
          throw ParseException('Too many tab characters: &', parser.nextToken);
        } else {
          // {array} environment
          parser.settings.reportNonstrict('textEnv',
              'Too few columns specified in the {array} column argument.');
        }
      }
      parser.consume();
    } else if (next == '\\end') {
      endRow();
      // Arrays terminate newlines with `\crcr` which consumes a `\cr` if
      // the last line is empty. However, AMS environments keep the empty
      // row if it's the only one, has a manual tag, or is an automatically
      // numbered row explicitly ended with `\\`.
      if (row.length == 1 &&
          cellBody.isEmpty &&
          (body.length > 1 || !emptySingleRow) &&
          tags?.lastOrNull == null &&
          !autoNumbered) {
        body.removeLast();
        if (tags != null) tags.removeLast();
      }
      if (hLinesBeforeRow.length < body.length + 1) {
        hLinesBeforeRow.add(MatrixSeparatorStyle.none);
      }
      break;
    } else if (next == '\\\\') {
      parser.consume();
      // \def\math@cr@{\new@ifnextchar[\math@cr@@{\math@cr@@[\z@]}}
      Measurement? size;
      if (gullet.future().text != ' ') {
        size = parser.parseSizeGroup(optional: true);
      }
      rowGaps.add(size ?? Measurement.zero);
      endRow();

      // check for \hline(s) following the row separator
      hLinesBeforeRow
          .add(getHLines(parser).lastOrNull ?? MatrixSeparatorStyle.none);

      row = [];
      body.add(row);
      beginRow();
    } else {
      throw ParseException(
          'Expected & or \\\\ or \\cr or \\end', parser.nextToken);
    }
  }

  // End cell group
  gullet.endGroup();
  // End array group defining \cr
  gullet.endGroup();

  return ArrayBody(
    body: body,
    rowGaps: rowGaps,
    hLines: hLinesBeforeRow,
    tags: tags,
    arrayStretch: arrayStretch,
  );
}

/// Parse the body of the environment, with rows delimited by \\ and
/// columns delimited by &, and create a nested list in row-major order
/// with one group per cell.  If given an optional argument style
/// ('text', 'display', etc.), then each cell is cast into that style.
MatrixNode parseArray(
  TexParser parser, {
  bool hskipBeforeAndAfter = false,
  double? arrayStretch,
  List<MatrixSeparatorStyle> separators = const [],
  List<MatrixColumnAlign> colAligns = const [],
  MathStyle? style,
  bool isSmall = false,
  int? maxNumCols,
}) {
  final res = parseArrayBody(
    parser,
    arrayStretch: arrayStretch,
    style: style,
    maxNumCols: maxNumCols,
  );
  return MatrixNode(
    body: res.body,
    vLines: separators,
    columnAligns: colAligns,
    rowSpacings: res.rowGaps,
    arrayStretch: res.arrayStretch,
    hLines: res.hLines,
    hskipBeforeAndAfter: hskipBeforeAndAfter,
    isSmall: isSmall,
  );
}

/// Decides on a style for cells in an array according to whether the given
/// environment name starts with the letter 'd'.
MathStyle _dCellStyle(String envName) =>
    envName.substring(0, 1) == 'd' ? MathStyle.display : MathStyle.text;

// const _alignMap = {
//   'c': 'center',
//   'l': 'left',
//   'r': 'right',
// };

// class ColumnConf {
//   final List<String> separators;
//   final List<_AlignSpec> aligns;
//   // final bool hskipBeforeAndAfter;
//   // final double arrayStretch;
//   ColumnConf({
//     required this.separators,
//     required this.aligns,
//     // this.hskipBeforeAndAfter = false,
//     // this.arrayStretch = 1,
//   });
// }

GreenNode _arrayHandler(TexParser parser, EnvContext context) {
  final symArg = parser.parseArgNode(mode: null, optional: false);
  final colalign = symArg is SymbolNode
      ? [symArg]
      : assertNodeType<EquationRowNode>(symArg).children;
  final separators = <MatrixSeparatorStyle>[];
  final aligns = <MatrixColumnAlign>[];
  var alignSpecified = true;
  var lastIsSeparator = false;

  for (final nde in colalign) {
    final node = assertNodeType<SymbolNode>(nde);
    final ca = node.symbol;
    switch (ca) {
      //ignore_for_file: switch_case_completes_normally
      case 'l':
      case 'c':
      case 'r':
        aligns.add(const {
          'l': MatrixColumnAlign.left,
          'c': MatrixColumnAlign.center,
          'r': MatrixColumnAlign.right,
        }[ca]!);
        if (alignSpecified) {
          separators.add(MatrixSeparatorStyle.none);
        }
        alignSpecified = true;
        lastIsSeparator = false;
        break;
      case '|':
      case ':':
        if (alignSpecified) {
          separators.add(const {
            '|': MatrixSeparatorStyle.solid,
            ':': MatrixSeparatorStyle.dashed,
          }[ca]!);
          // aligns.add(MatrixColumnAlign.center);
        }
        alignSpecified = false;
        lastIsSeparator = true;
        break;
      default:
        throw ParseException('Unknown column alignment: $ca');
    }
  }
  if (!lastIsSeparator) {
    separators.add(MatrixSeparatorStyle.none);
  }
  return parseArray(
    parser,
    separators: separators,
    colAligns: aligns,
    hskipBeforeAndAfter: true,
    style: _dCellStyle(context.envName),
    maxNumCols: aligns.length,
  );
}

GreenNode _matrixHandler(TexParser parser, EnvContext context) {
  final baseName = context.envName.replaceAll('*', '');
  final delimiters = const {
    'matrix': null,
    'pmatrix': ['(', ')'],
    'bmatrix': ['[', ']'],
    'Bmatrix': ['{', '}'],
    'vmatrix': ['|', '|'],
    'Vmatrix': ['\u2223', '\u2223'],
  }[baseName];
  var colAlign = MatrixColumnAlign.center;
  if (context.envName.endsWith('*')) {
    // It's one of the mathtools starred functions.
    // Parse the optional alignment argument.
    parser.consumeSpaces();
    if (parser.fetch().text == '[') {
      parser.consume();
      parser.consumeSpaces();
      final align = parser.fetch().text;
      colAlign = switch (align) {
        'l' => MatrixColumnAlign.left,
        'c' => MatrixColumnAlign.center,
        'r' => MatrixColumnAlign.right,
        _ => throw ParseException('Expected l or c or r', parser.nextToken),
      };
      parser.consume();
      parser.consumeSpaces();
      parser.expect(']');
    }
  }
  final body = parseArrayBody(parser, style: _dCellStyle(context.envName));
  final numCols = body.body.fold(0, (n, row) => math.max(n, row.length));
  final res = MatrixNode(
    body: body.body,
    columnAligns: List.filled(numCols, colAlign),
    rowSpacings: body.rowGaps,
    arrayStretch: body.arrayStretch,
    hLines: body.hLines,
    hskipBeforeAndAfter: false,
  );
  return delimiters == null
      ? res
      : LeftRightNode(
          leftDelim: delimiters[0],
          rightDelim: delimiters[1],
          body: [
            [res].wrapWithEquationRow()
          ],
        );
}

GreenNode _smallMatrixHandler(TexParser parser, EnvContext context) =>
    parseArray(
      parser,
      arrayStretch: 0.5,
      style: MathStyle.script,
      isSmall: true,
    );

GreenNode _subArrayHandler(TexParser parser, EnvContext context) {
  // Parsing of {subarray} is similar to {array}
  final symArg = parser.parseArgNode(mode: null, optional: false);
  final colalign = symArg is SymbolNode
      ? [symArg]
      : assertNodeType<EquationRowNode>(symArg).children;
  // final separators = <MatrixSeparatorStyle>[];
  final aligns = <MatrixColumnAlign>[];
  for (final nde in colalign) {
    final node = assertNodeType<SymbolNode>(nde);
    final ca = node.symbol;
    if (ca == 'l' || ca == 'c') {
      aligns.add(ca == 'l' ? MatrixColumnAlign.left : MatrixColumnAlign.center);
    } else {
      throw ParseException('Unknown column alignment: $ca');
    }
  }
  if (aligns.length > 1) {
    throw ParseException('{subarray} can contain only one column');
  }
  final res = parseArray(
    parser,
    colAligns: aligns,
    hskipBeforeAndAfter: false,
    arrayStretch: 0.5,
    style: MathStyle.script,
  );
  if (res.body.isNotEmpty && res.body[0].length > 1) {
    throw ParseException('{subarray} can contain only one column');
  }
  return res;
}
