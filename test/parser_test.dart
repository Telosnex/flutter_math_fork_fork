// Parser behavior from KaTeX v0.19.1 src/Parser.ts: argument parsing
// (#2085), allowedInArgument (#2134), \relax (#4045), colors (#4090).
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'load_fonts.dart';

EquationRowNode parse(String tex) =>
    TexParser(tex, const TexParserSettings()).parse();

Matcher get parses => returnsNormally;
Matcher get fails => throwsA(isA<ParseException>());

void main() {
  setUpAll(loadKaTeXFonts);

  group('allowedInArgument', () {
    test(r'\frac is allowed as a script without braces', () {
      expect(() => parse(r'x^\frac12'), parses);
    });
    test(r'\sqrt is not', () {
      expect(() => parse(r'x^\sqrt2'), fails);
    });
    test(r'a font command is allowed', () {
      expect(() => parse(r'x^\mathrm a'), parses);
    });
  });

  group('macro arguments', () {
    test('an argument can come from a macro expansion', () {
      expect(() => parse(r'\def\a{{x}}\frac\a y'), parses);
    });
    test('an argument is one token without braces', () {
      final frac = parse(r'\frac ab').children.single as FracNode;
      expect(frac.numerator.children.single, isA<SymbolNode>());
      expect(frac.denominator.children.single, isA<SymbolNode>());
    });
    test('a missing argument is an error', () {
      expect(() => parse(r'\frac a'), fails);
    });
  });

  group(r'\relax', () {
    test('is dropped from the expression', () {
      expect(parse(r'x\relax y').children, hasLength(2));
    });
    test('ends a size', () {
      expect(() => parse(r'\kern2\relax em'), fails);
      expect(() => parse(r'\kern2em\relax x'), parses);
    });
    test('is skipped before a script argument (#4045)', () {
      final node = parse(r'x^\relax 2').children.single as MultiscriptsNode;
      expect(node.sup!.children.single, isA<SymbolNode>());
    });
    test(r'\quad (\hskip1em\relax) works in text', () {
      expect(() => parse(r'\text{a\quad b}'), parses);
    });
  });

  group(r'\\ and size', () {
    test(r'\\[1ex] reads a size', () {
      expect(() => parse(r'a\\[1ex]b'), parses);
    });
    test(r'\\ [b] is a break before "[b]"', () {
      expect(() => parse(r'a\\ [b]'), parses);
    });
  });

  group('colors (#4090)', () {
    for (final (tex, argb) in [
      ('#abc', 0xffaabbcc),
      ('#abc8', 0x88aabbcc),
      ('#ff000080', 0x80ff0000),
      ('ff0000', 0xffff0000),
      ('red', null),
    ]) {
      test(tex, () {
        final style =
            parse('\\textcolor{$tex}{x}').children.single as StyleNode;
        final color = style.optionsDiff.color!;
        if (argb != null) expect(color.toARGB32(), argb);
      });
    }
    test('5 hex digits are invalid', () {
      expect(() => parse(r'\textcolor{#fA6f1}{x}'), fails);
    });
  });

  group('operands of operators', () {
    test(r'a line break is not the operand of \sin', () {
      expect(parse(r'\sin \\ x').children.single, isA<EquationArrayNode>());
    });
    test(r'\relax is not an operand', () {
      expect(() => parse(r'\sum\relax x'), parses);
    });
    testWidgets(r'\sin \\ x and \operatorname{f} \\ x render', (tester) async {
      for (final tex in [
        r'\sin \\ x',
        r'\operatorname{f} \\ x',
        r'\sum\relax x'
      ]) {
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Math.tex(tex, onErrorFallback: (e) => throw e),
        ));
        expect(tester.takeException(), isNull, reason: tex);
      }
    });
  });

  test('local macros are removed after a parse error (#3114)', () {
    // One parser, as in KaTeX's test: the error must not leave \foo.
    final parser = TexParser(r'\def\foo{x} \frac', const TexParserSettings());
    expect(parser.parse, fails);
    expect(parser.macroExpander.macros.has(r'\foo'), isFalse);
  });
}
