import 'package:flutter_math_fork_fork/flutter_math.dart';
import 'package:flutter_math_fork_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ParseException.toString gives the message', () {
    try {
      TexParser(r'\frac{a}', const TexParserSettings()).parse();
      fail('expected a ParseException');
    } on ParseException catch (e) {
      expect(e.toString(), startsWith('Parser Error: '));
      expect(e.toString(), isNot(contains('Instance of')));
      expect(e.message, contains(e.rawMessage));
      expect(e.rawMessage, isNot(contains('position')));
    }
  });

  test('BuildException.toString gives the message', () {
    expect(
      const BuildException('oops').toString(),
      'Build Exception: oops',
    );
  });
}
