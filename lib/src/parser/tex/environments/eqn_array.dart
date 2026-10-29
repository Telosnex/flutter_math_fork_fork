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

import '../../../ast/nodes/equation_array.dart';
import '../../../ast/nodes/left_right.dart';
import '../../../ast/nodes/space.dart';
import '../../../ast/nodes/style.dart';
import '../../../ast/options.dart';
import '../../../ast/size.dart';
import '../../../ast/style.dart';
import '../../../ast/syntax_tree.dart';
import '../../../ast/types.dart';
import '../define_environment.dart';
import '../functions/katex_base.dart';
import '../parse_error.dart';
import '../parser.dart';
import 'array.dart';

const eqnArrayEntries = {
  [
    'cases',
    'dcases',
    'rcases',
    'drcases',
  ]: EnvSpec(
    numArgs: 0,
    handler: _casesHandler,
  ),
  ['align', 'align*', 'aligned', 'split']: EnvSpec(
    numArgs: 0,
    handler: _alignedHandler,
  ),
  ['gathered', 'gather', 'gather*']:
      EnvSpec(numArgs: 0, handler: _gatheredHandler),
  ['alignat', 'alignat*', 'alignedat']:
      EnvSpec(numArgs: 1, handler: _alignedHandler),
  ['equation', 'equation*']: EnvSpec(numArgs: 0, handler: _equationHandler),
};

void _validateAmsEnvironmentContext(TexParser parser, EnvContext context) {
  if (!parser.settings.displayMode) {
    throw ParseException(
        '{${context.envName}} can be used only in display mode.');
  }
}

/// KaTeX getAutoTag: null for the -ed environments, else numbered unless
/// starred. Not for "split".
bool? _getAutoTag(String name) =>
    name.contains('ed') ? null : !name.contains('*');

GreenNode _casesHandler(TexParser parser, EnvContext context) {
  final body = parseEqnArray(
    parser,
    concatRow: (cells) {
      final children = [
        SpaceNode.alignerOrSpacer(),
        if (cells.isNotEmpty) ...cells[0].children,
        if (cells.length > 1) SpaceNode.alignerOrSpacer(),
        if (cells.length > 1)
          SpaceNode(height: Measurement.zero, width: 1.0.em, mode: Mode.math),
      ];
      for (var i = 1; i < cells.length; i++) {
        children.add(SpaceNode.alignerOrSpacer());
        children.addAll(cells[i].children);
        children.add(SpaceNode.alignerOrSpacer());
      }
      if (context.envName == 'dcases' || context.envName == 'drcases') {
        return EquationRowNode(children: [
          StyleNode(
            optionsDiff: OptionsDiff(style: MathStyle.display),
            children: children,
          )
        ]);
      } else {
        return EquationRowNode(children: children);
      }
    },
  );
  if (context.envName == 'rcases' || context.envName == 'drcases') {
    return LeftRightNode(
      leftDelim: null,
      rightDelim: '}',
      body: [body.wrapWithEquationRow()],
    );
  } else {
    return LeftRightNode(
      leftDelim: '{',
      rightDelim: null,
      body: [body.wrapWithEquationRow()],
    );
  }
}

/// align, align*, aligned, split, alignat, alignat*, alignedat.
GreenNode _alignedHandler(TexParser parser, EnvContext context) {
  if (!context.envName.contains('ed')) {
    _validateAmsEnvironmentContext(parser, context);
  }
  final isAlignAt = context.envName.contains('at');
  int? numMaths;
  if (isAlignAt) {
    const message = 'Number of columns should be a positive integer';
    final string = assertCharacterGroup(
      parser,
      parser.parseArgNode(mode: null, optional: false),
      message,
    );
    numMaths = RegExp(r'^[0-9]+$').hasMatch(string) ? int.parse(string) : 0;
    if (numMaths < 1) throw ParseException(message);
  }
  final isSplit = context.envName == 'split';
  return parseEqnArray(
    parser,
    addJot: true,
    autoTag: isSplit ? null : _getAutoTag(context.envName),
    emptySingleRow: true,
    strictColumns: true,
    maxNumCols: isSplit ? 2 : null,
    concatRow: (cells) {
      if (numMaths != null && cells.length / 2 > numMaths) {
        throw ParseException('Too many math in a row: '
            'expected $numMaths, but got ${cells.length / 2}');
      }
      final expanded = cells
          .expand((cell) => [...cell.children, SpaceNode.alignerOrSpacer()])
          .toList(growable: true);
      return EquationRowNode(children: expanded);
    },
  );
}

// A gathered environment is like an array environment with one centered
// column, but where rows are considered lines so get \jot line spacing
// and contents are set in \displaystyle.
GreenNode _gatheredHandler(TexParser parser, EnvContext context) {
  if (context.envName != 'gathered') {
    _validateAmsEnvironmentContext(parser, context);
  }
  return parseEqnArray(
    parser,
    addJot: true,
    autoTag: _getAutoTag(context.envName),
    emptySingleRow: true,
    concatRow: (cells) => EquationRowNode(
      children: [for (final cell in cells) ...cell.children],
    ),
  );
}

GreenNode _equationHandler(TexParser parser, EnvContext context) {
  _validateAmsEnvironmentContext(parser, context);
  return parseEqnArray(
    parser,
    autoTag: _getAutoTag(context.envName),
    emptySingleRow: true,
    singleRow: true,
    maxNumCols: 1,
    concatRow: (cells) => cells.single,
  );
}

EquationArrayNode parseEqnArray(
  TexParser parser, {
  bool addJot = false,
  bool? autoTag,
  bool singleRow = false,
  bool emptySingleRow = false,
  bool strictColumns = false,
  int? maxNumCols,
  required EquationRowNode Function(List<EquationRowNode> cells) concatRow,
}) {
  final res = parseArrayBody(
    parser,
    autoTag: autoTag,
    singleRow: singleRow,
    emptySingleRow: emptySingleRow,
    strictColumns: strictColumns,
    maxNumCols: maxNumCols,
  );
  final rows = <EquationRowNode>[];
  for (var i = 0; i < res.body.length; i++) {
    final cells = res.body[i];
    final tag = res.tags?[i];
    // Dart divergence: the tag follows the last cell of its row after a
    // \qquad. KaTeX puts it at the right edge of the display.
    if (tag != null && cells.isNotEmpty) {
      cells.last = EquationRowNode(children: [
        ...cells.last.children,
        SpaceNode(height: Measurement.zero, width: 2.0.em, mode: Mode.math),
        ...tag,
      ]);
    }
    rows.add(concatRow(cells));
  }
  return EquationArrayNode(
    arrayStretch: res.arrayStretch,
    hlines: res.hLines,
    rowSpacings: res.rowGaps,
    addJot: addJot,
    body: rows,
  );
}
