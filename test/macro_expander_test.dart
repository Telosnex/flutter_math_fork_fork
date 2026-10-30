// MacroExpander behavior from KaTeX v0.19.1 src/MacroExpander.ts.
import 'package:flutter_math_fork_fork/ast.dart';
import 'package:flutter_math_fork_fork/flutter_math.dart';
import 'package:flutter_math_fork_fork/src/parser/tex/macro_expander.dart';
import 'package:flutter_math_fork_fork/src/parser/tex/token.dart';
import 'package:flutter_test/flutter_test.dart';

MacroExpander gullet(String input) =>
    MacroExpander(input, const TexParserSettings(), Mode.math);

List<String> texts(List<Token> reversed) =>
    reversed.reversed.map((t) => t.text).toList();

void main() {
  test('undelimited argument skips spaces and removes outer braces', () {
    final g = gullet('  {a{b}c} d');
    expect(texts(g.consumeArg().tokens), ['a', '{', 'b', '}', 'c']);
    expect(texts(g.consumeArg().tokens), ['d']);
  });

  test('delimited argument stops at the delimiter, at depth 0', () {
    final g = gullet('a{]}b]c');
    final arg = g.consumeArg([']']);
    expect(texts(arg.tokens), ['a', '{', ']', '}', 'b']);
    expect(g.popToken().text, 'c');
  });

  test('Extra } is an error', () {
    expect(
        () => gullet('a}').consumeArg([']']), throwsA(isA<ParseException>()));
  });

  test('expandOnce returns the token count, or null when not expanded', () {
    final g = gullet(r'\TeX x');
    expect(g.expandOnce(), greaterThan(0));
    final g2 = gullet('x');
    expect(g2.expandOnce(), isNull);
    expect(g2.future().text, 'x');
  });

  test('scanArgument pushes the argument with an EOF marker', () {
    final g = gullet('[ab]c');
    final span = g.scanArgument(isOptional: true);
    expect(span, isNotNull);
    expect([for (var i = 0; i < 3; i++) g.popToken().text], ['a', 'b', 'EOF']);
    expect(g.popToken().text, 'c');
    expect(gullet('x').scanArgument(isOptional: true), isNull);
  });

  test('expandable-only expansion of an undefined command is an error', () {
    final g = gullet(r'\undefinedcommand');
    expect(() => g.expandOnce(true), throwsA(isA<ParseException>()));
  });

  test('expandable-only expansion of a defined non-macro keeps it', () {
    final g = gullet(r'\alpha');
    expect(g.expandOnce(true), isNull);
    expect(g.future().text, r'\alpha');
  });
}
