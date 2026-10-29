// katex-sync: src/Lexer.ts @ v0.19.1
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

import 'parse_error.dart';
import 'settings.dart';
import 'source_location.dart';
import 'token.dart';

/// The token regex. Capturing groups:
///   [1] regular whitespace
///   [2] backslash followed by whitespace
///   [3] anything else, which may include:
///     [4] left character of \verb*
///     [5] left character of \verb
///     [6] backslash followed by word, excluding any trailing whitespace
const spaceRegexString = '[ \r\n\t]';
const controlWordRegexString = '\\\\[a-zA-Z@]+';
const controlSymbolRegexString = '\\\\[^\uD800-\uDFFF]';
const controlWordWhitespaceRegexString =
    '($controlWordRegexString)$spaceRegexString*';
const controlSpaceRegexString = '\\\\(\n|[ \r\t]+\n?)[ \r\t]*';
const combiningDiacriticalMarkString = '[\u0300-\u036f]';
final combiningDiacriticalMarksEndRegex =
    RegExp('$combiningDiacriticalMarkString+\$');
const tokenRegexString = '($spaceRegexString+)|' // whitespace
    '$controlSpaceRegexString|' // \whitespace
    '([!-\\[\\]-\u2027\u202A-\uD7FF\uF900-\uFFFF]' // single codepoint
    '$combiningDiacriticalMarkString*' // ...plus accents
    '|[\uD800-\uDBFF][\uDC00-\uDFFF]' // surrogate pair
    '$combiningDiacriticalMarkString*' // ...plus accents
    '|\\\\verb\\*([^]).*?\\4' // \verb*
    '|\\\\verb([^*a-zA-Z]).*?\\5' // \verb unstarred
    '|$controlWordWhitespaceRegexString' // \macroName + spaces
    '|$controlSymbolRegexString)'; // \\, \', etc.

abstract class LexerInterface {
  String get input;
}

class Lexer implements LexerInterface {
  static final tokenRegex = RegExp(tokenRegexString);

  Lexer(this.input, this.settings);

  @override
  final String input;
  final TexParserSettings settings;

  /// Category codes. The lexer only supports comment characters (14).
  /// MacroExpander also distinguishes active characters (13).
  final Map<String, int> catCodes = {
    '%': 14, // comment character
    '~': 13, // active character
  };

  /// The position of the next token. KaTeX: tokenRegex.lastIndex.
  int pos = 0;

  void setCatcode(String char, int code) => catCodes[char] = code;

  /// Lexes a single token.
  Token lex() {
    if (pos == input.length) {
      return Token('EOF', SourceLocation(this, pos, pos));
    }
    final match = tokenRegex.matchAsPrefix(input, pos);
    if (match == null) {
      throw ParseException("Unexpected character: '${input[pos]}'",
          Token(input[pos], SourceLocation(this, pos, pos + 1)));
    }
    final start = pos;
    pos = match.end;
    final text = match[6] ?? match[3] ?? (match[2] != null ? '\\ ' : ' ');

    if (catCodes[text] == 14) {
      // comment character
      final nlIndex = input.indexOf('\n', pos);
      if (nlIndex == -1) {
        pos = input.length; // EOF
        settings.reportNonstrict(
            'commentAtEnd',
            '% comment has no terminating newline; LaTeX would '
                'fail because of commenting the end of math mode (e.g. \$)');
      } else {
        pos = nlIndex + 1;
      }
      return lex();
    }

    return Token(text, SourceLocation(this, start, pos));
  }
}
