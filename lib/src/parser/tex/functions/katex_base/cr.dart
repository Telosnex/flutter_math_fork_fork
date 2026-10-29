// katex-sync: src/functions/cr.ts @ v0.19.1
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

part of '../katex_base.dart';

// Row breaks within tabular environments, and line breaks at top level

// \\ is a TeX primitive; \newline (macros.dart) is \\\relax. \cr is
// defined only inside arrays.
const _crEntries = {
  ['\\\\']: FunctionSpec(numArgs: 0, handler: _crHandler),
};

class CrNode extends TemporaryNode {
  final bool newLine;
  final Measurement? size;
  CrNode({required this.newLine, this.size});
}

GreenNode _crHandler(TexParser parser, FunctionContext context) {
  final next = parser.nextToken ?? parser.macroExpander.future();
  final size = next.text == '[' ? parser.parseArgSize(optional: true) : null;
  // In LaTeX, \\ does nothing in display mode.
  final newLine = !parser.settings.displayMode ||
      !parser.settings.useStrictBehavior(
          'newLineInDisplayMode',
          'In LaTeX, \\\\ or \\newline '
              'does nothing in display mode');
  return CrNode(newLine: newLine, size: size);
}
