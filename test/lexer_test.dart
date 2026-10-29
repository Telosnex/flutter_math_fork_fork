// Lexer behavior from KaTeX v0.19.1 src/Lexer.ts.
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/lexer.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> lexAll(String input) {
  final lexer = Lexer(input, const TexParserSettings());
  final tokens = <String>[];
  while (true) {
    final token = lexer.lex();
    if (token.text == 'EOF') return tokens;
    tokens.add(token.text);
  }
}

void main() {
  test('control word drops trailing whitespace', () {
    expect(lexAll(r'\alpha  x'), [r'\alpha', 'x']);
  });

  test('backslash before whitespace is a control space (KaTeX #2877)', () {
    expect(lexAll('a\\ \n  b'), ['a', r'\ ', 'b']);
    expect(lexAll('a\\\n  b'), ['a', r'\ ', 'b']);
    expect(lexAll('a\\\t\tb'), ['a', r'\ ', 'b']);
  });

  test('\\operatorname* is two tokens; a macro handles the star (#2984)', () {
    expect(
        lexAll(r'\operatorname*{x}'), [r'\operatorname', '*', '{', 'x', '}']);
  });

  test('comment skips to the next line', () {
    expect(lexAll('a%comment\nb'), ['a', 'b']);
  });

  test('source locations', () {
    final lexer = Lexer(r'x \beta', const TexParserSettings());
    final tokens = [lexer.lex(), lexer.lex(), lexer.lex()];
    expect(
      tokens.map((t) => (t.text, t.loc!.start, t.loc!.end)),
      [('x', 0, 1), (' ', 1, 2), (r'\beta', 2, 7)],
    );
  });

  test('\\operatorname and \\operatorname* still parse', () {
    expect(
      () => TexParser(r'\operatorname{f}(x) + \operatorname*{arg\,max}_x y',
              const TexParserSettings())
          .parse(),
      returnsNormally,
    );
  });
}
