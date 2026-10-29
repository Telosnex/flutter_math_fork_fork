// katex-sync: src/parseTree.ts @ v0.19.1
// katex-sync: src/Parser.ts @ v0.19.1
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

import 'dart:collection';
import 'dart:ui';

import '../../ast/nodes/equation_array.dart';
import '../../ast/nodes/multiscripts.dart';
import '../../ast/nodes/over.dart';
import '../../ast/nodes/style.dart';
import '../../ast/nodes/symbol.dart';
import '../../ast/nodes/under.dart';
import '../../ast/options.dart';
import '../../ast/size.dart';
import '../../ast/style.dart';
import '../../ast/symbols/symbols_unicode.dart';
import '../../ast/syntax_tree.dart';
import '../../ast/types.dart';
import '../../font/metrics/unicode_scripts.dart';
import 'colors.dart';
import 'functions.dart';
import 'functions/katex_base.dart';
import 'lexer.dart';
import 'macro_expander.dart';
import 'macros.dart';
import 'parse_error.dart';
import 'settings.dart';
import 'symbols.dart';
import 'token.dart';
import 'unicode_accents.dart';

/// Parser for TeX equations
///
/// Convert TeX string to Flutter Math's AST
class TexParser {
  TexParser(String content, this.settings)
      : leftrightDepth = 0,
        mode = Mode.math,
        macroExpander = MacroExpander(content, settings, Mode.math);

  final TexParserSettings settings;
  Mode mode;
  int leftrightDepth;

  final MacroExpander macroExpander;
  Token? nextToken;

  /// Get parse result
  EquationRowNode parse() {
    // KaTeX parseTree: blank out any \df@tag to avoid spurious
    // "Duplicate \tag" errors.
    macroExpander.macros.current.remove('\\df@tag');
    if (!settings.globalGroup) {
      macroExpander.beginGroup();
    }
    if (settings.colorIsTextColor) {
      macroExpander.macros
          .set('\\color', MacroDefinition.fromString('\\textcolor'));
    }
    try {
      final parse = parseExpression(breakOnInfix: false);
      expect('EOF');
      if (!settings.globalGroup) {
        macroExpander.endGroup();
      }
      // KaTeX parseTree: \tag sets the \df@tag macro to the tag.
      if (macroExpander.macros.get('\\df@tag') != null) {
        if (!settings.displayMode) {
          throw ParseException('\\tag works only in display equations');
        }
        // Dart divergence: no tag layout. KaTeX puts the tag at the right
        // edge of the display; Dart puts it after the equation.
        final tag = subparse([Token('\\df@tag'), Token('\\qquad')]);
        return [...parse, ...tag].wrapWithEquationRow();
      }
      return parse.wrapWithEquationRow();
    } finally {
      // Remove local macros after a parse error (KaTeX #3114).
      macroExpander.endGroups();
    }
  }

  /// Parses [tokens] (in stack order) as an expression. KaTeX: subparse.
  List<GreenNode> subparse(List<Token> tokens) {
    final oldToken = nextToken;
    consume();
    macroExpander
      ..pushToken(Token('}'))
      ..pushTokens(tokens);
    final parse = parseExpression(breakOnInfix: false);
    expect('}');
    nextToken = oldToken;
    return parse;
  }

  List<GreenNode> parseExpression({
    bool breakOnInfix = false,
    String? breakOnTokenText,
    bool infixArgumentMode = false,
  }) {
    final body = <GreenNode>[];
    while (true) {
      if (mode == Mode.math) {
        consumeSpaces();
      }
      final lex = fetch();
      if (endOfExpression.contains(lex.text)) {
        break;
      }
      if (breakOnTokenText != null && lex.text == breakOnTokenText) {
        break;
      }
      // Detects a infix function
      final funcData = functions[lex.text];
      if (funcData != null && funcData.infix == true) {
        if (infixArgumentMode) {
          throw ParseException('only one infix operator per group', lex);
        }
        if (breakOnInfix) {
          break;
        }
        consume();
        _enterArgumentParsingMode(lex.text, funcData);
        try {
          // A new way to handle infix operations
          final atom = funcData.handler(
            this,
            FunctionContext(
              funcName: lex.text,
              breakOnTokenText: breakOnTokenText,
              token: lex,
              infixExistingArguments: List.of(body, growable: false),
            ),
          );
          body.clear();
          body.add(atom);
        } finally {
          _leaveArgumentParsingMode(lex.text);
        }
      } else {
        // Add a normal atom
        final atom = parseAtom(breakOnTokenText);
        if (atom == null) {
          break;
        } else if (atom is InternalNode) {
          continue;
        }
        body.add(atom);
      }
    }

    return _splitLines(body);
    // We will NOT handle ligatures between '-' and "'", as neither did MathJax.
    // if (this.mode == Mode.text) {
    //   formLigatures(body);
    // }
    // We will not handle infix as well
    // return handleInfixNodes(body);
  }

  static const Set<String> breakTokens = {
    ']',
    '}',
    '\\endgroup',
    '\$',
    '\\)',
    '\\cr',
  };

  /// Line breaks outside arrays. KaTeX (src/functions/cr.ts) renders a
  /// `\\` with newLine as a line break, and one without newLine (display
  /// mode, strict) as nothing. Arrays consume their own `\\`, so a CrNode
  /// here is a line break. Dart builds the lines as rows of an
  /// EquationArrayNode.
  static List<GreenNode> _splitLines(List<GreenNode> body) {
    if (!body.any((node) => node is CrNode)) return body;
    final rows = <EquationRowNode>[];
    final spacings = <Measurement>[];
    var line = <GreenNode>[];
    for (final node in body) {
      if (node is! CrNode) {
        line.add(node);
      } else if (node.newLine || node.newRow) {
        rows.add(line.wrapWithEquationRow());
        spacings.add(node.size ?? Measurement.zero);
        line = [];
      }
    }
    if (rows.isEmpty) return line;
    // As in LaTeX, a break at the end makes no empty last line.
    if (line.isNotEmpty) {
      rows.add(line.wrapWithEquationRow());
    } else {
      spacings.removeLast();
    }
    if (rows.length == 1) return rows.single.children;
    return [EquationArrayNode(body: rows, rowSpacings: spacings)];
  }

  static const Set<String> endOfExpression = {
    '}',
    '\\endgroup',
    '\\end',
    '\\right',
    '&',
  };

  static const Map<String, String> endOfGroup = {
    '[': ']',
    '{': '}',
    '\\begingroup': '\\endgroup',
  };

  void expect(String text, {bool consume = true}) {
    if (fetch().text != text) {
      throw ParseException(
          'Expected \'$text\', got \'${fetch().text}\'', fetch());
    }
    if (consume) {
      this.consume();
    }
  }

  void consumeSpaces() {
    while (fetch().text == ' ') {
      consume();
    }
  }

  GreenNode? parseAtom(String? breakOnTokenText) {
    final base = parseGroup('atom', breakOnTokenText: breakOnTokenText);

    if (base is InternalNode || mode == Mode.text) {
      return base;
    }

    final scriptsResult = parseScripts(
        allowLimits:
            base is EquationRowNode && base.overrideType == AtomType.op);

    if (!scriptsResult.empty) {
      if (scriptsResult.limits != true) {
        return MultiscriptsNode(
          base: base?.wrapWithEquationRow() ?? EquationRowNode.empty(),
          sub: scriptsResult.subscript,
          sup: scriptsResult.superscript,
        );
      } else {
        var res = scriptsResult.superscript != null
            ? OverNode(
                base: base?.wrapWithEquationRow() ?? EquationRowNode.empty(),
                above: scriptsResult.superscript!)
            : base;
        res = scriptsResult.subscript != null
            ? UnderNode(
                base: res?.wrapWithEquationRow() ?? EquationRowNode.empty(),
                below: scriptsResult.subscript!)
            : res;
        return res;
      }
    } else {
      return base;
    }
  }

  /// The following functions are separated from parseAtoms in KaTeX
  /// This function will only be invoked in math mode
  ScriptsParsingResults parseScripts({bool allowLimits = false}) {
    EquationRowNode? subscript;
    EquationRowNode? superscript;
    bool? limits;
    loop:
    while (true) {
      consumeSpaces();
      final lex = fetch();
      switch (lex.text) {
        case '\\limits':
        case '\\nolimits':
          if (!allowLimits) {
            throw ParseException(
                'Limit controls must follow a math operator', lex);
          }
          limits = lex.text == '\\limits';
          consume();
          break;
        case '^':
          if (superscript != null) {
            throw ParseException('Double superscript', lex);
          }
          superscript = _handleScript().wrapWithEquationRow();
          break;
        case '_':
          if (subscript != null) {
            throw ParseException('Double subscript', lex);
          }
          subscript = _handleScript().wrapWithEquationRow();
          break;
        case "'":
          if (superscript != null) {
            throw ParseException('Double superscript', lex);
          }
          final primeCommand = texSymbolCommandConfigs[Mode.math]!['\\prime']!;
          final superscriptList = <GreenNode>[
            SymbolNode(
              mode: mode,
              symbol: primeCommand.symbol,
              variantForm: primeCommand.variantForm,
              overrideAtomType: primeCommand.type,
              overrideFont: primeCommand.font,
            ),
          ];
          consume();
          while (fetch().text == "'") {
            superscriptList.add(
              SymbolNode(
                mode: mode,
                symbol: primeCommand.symbol,
                variantForm: primeCommand.variantForm,
                overrideAtomType: primeCommand.type,
                overrideFont: primeCommand.font,
              ),
            );
            consume();
          }
          if (fetch().text == '^') {
            superscriptList.addAll(_handleScript().expandEquationRow());
          }
          superscript = superscriptList.wrapWithEquationRow();
          break;
        default:
          break loop;
      }
    }
    return ScriptsParsingResults(
      subscript: subscript,
      superscript: superscript,
      limits: limits,
    );
  }

  GreenNode _handleScript() {
    final symbolToken = fetch();
    final symbol = symbolToken.text;
    consume();
    consumeSpaces(); // ignore spaces before sup/subscript argument
    GreenNode? group;
    do {
      group = parseGroup(symbol == '_' ? 'subscript' : 'superscript');
    } while (group is InternalNode);
    if (group == null) {
      throw ParseException("Expected group after '$symbol'", symbolToken);
    }
    return group;
  }

  Token fetch() {
    final nextToken = this.nextToken;
    if (nextToken == null) {
      return this.nextToken = macroExpander.expandNextToken();
    }
    return nextToken;
  }

  void consume() {
    nextToken = null;
  }

  /// Parses an ordinary group: a single nucleus (like "x"), a function
  /// with its arguments, or an expression in braces (like "{x+y}") or in
  /// `\begingroup`...`\endgroup`. Returns a row for a braced group.
  ///
  /// [name] is for errors. Unless it is 'atom', a function without
  /// allowedInArgument is an error (KaTeX #2134).
  GreenNode? parseGroup(String name, {String? breakOnTokenText}) {
    final firstToken = fetch();
    final text = firstToken.text;
    GreenNode? result;
    if (text == '{' || text == '\\begingroup') {
      consume();
      final groupEnd = endOfGroup[text]!;
      macroExpander.beginGroup();
      final expression =
          parseExpression(breakOnInfix: false, breakOnTokenText: groupEnd);
      expect(groupEnd);
      macroExpander.endGroup();
      result = expression.wrapWithEquationRow();
    } else {
      result = parseFunction(breakOnTokenText, name) ?? _parseSymbol();
      if (result == null &&
          text[0] == '\\' &&
          !implicitCommands.contains(text)) {
        if (settings.throwOnError) {
          throw ParseException('Undefined control sequence: $text', firstToken);
        }
        result = _formatUnsuppotedCmd(text);
        consume();
      }
    }
    return result;
  }

  ///Parses an entire function, including its base and all of its arguments.

  GreenNode? parseFunction(String? breakOnTokenText, String? name) {
    final token = fetch();
    final func = token.text;
    final funcData = functions[func];
    if (funcData == null) {
      return null;
    }
    consume();

    if (name != null && name != 'atom' && !funcData.allowedInArgument) {
      throw ParseException(
          "Got function '$func' with no arguments as $name", token);
    } else if (mode == Mode.text && !funcData.allowedInText) {
      throw ParseException(
          '''Can't use function '$func' in text mode''', token);
    } else if (mode == Mode.math && funcData.allowedInMath == false) {
      throw ParseException(
          '''Can't use function '$func' in math mode''', token);
    }

    // final funcArgs = parseArgument(func, funcData);

    final context = FunctionContext(
      funcName: func,
      token: token,
      breakOnTokenText: breakOnTokenText,
    );

    // if (funcData.handler != null) {
    _enterArgumentParsingMode(func, funcData);
    try {
      return funcData.handler(this, context);
    } finally {
      _leaveArgumentParsingMode(func);
    }
    // } else {
    //   throw ParseException('''No function handler for $name''');
    // }
    // return this.callFunction(func, token, breakOnTokenText);
  }

  final argParsingContexts = Queue<ArgumentParsingContext>();

  ArgumentParsingContext get currArgParsingContext => argParsingContexts.last;

  void _enterArgumentParsingMode(String name, FunctionSpec funcData) {
    argParsingContexts
        .addLast(ArgumentParsingContext(funcName: name, funcData: funcData));
  }

  void _leaveArgumentParsingMode(String name) {
    assert(currArgParsingContext.funcName == name);
    argParsingContexts.removeLast();
  }

  /// Arguments are read from the gullet (KaTeX #2085). A handler can fetch
  /// a token to look at it before it reads an argument. Give such a token
  /// back to the gullet first. KaTeX handlers get their arguments before
  /// they run, so KaTeX has no such step.
  void _returnFetchedToken() {
    final token = nextToken;
    if (token != null) {
      macroExpander.pushToken(token);
      nextToken = null;
    }
  }

  /// KaTeX: parseColorGroup.
  static final _colorRegex = RegExp(
    r'^(#[a-f0-9]{3,4}|#[a-f0-9]{6}|#[a-f0-9]{8}|[a-f0-9]{6}|[a-z]+)$',
    caseSensitive: false,
  );
  static final _hexColorRegex =
      RegExp(r'^#?([a-f0-9]+)$', caseSensitive: false);

  Color? parseArgColor({required bool optional}) {
    currArgParsingContext.newArgument(optional: optional);
    _returnFetchedToken();
    final res = _parseStringGroup(optional: optional);
    if (res == null) {
      _assertOptionalBeforeReturn(null, optional: optional);
      return null;
    }
    if (!_colorRegex.hasMatch(res.text)) {
      throw ParseException("Invalid color: '${res.text}'", res);
    }
    final hex = _hexColorRegex.firstMatch(res.text)?[1];
    if (hex != null && (res.text.startsWith('#') || hex.length == 6)) {
      return _hexColor(hex);
    }
    final color = colorByName[res.text.toLowerCase()];
    if (color != null) return color;
    // Dart divergence: KaTeX accepts any name and leaves it to CSS.
    throw ParseException("Invalid color: '${res.text}'", res);
  }

  /// `RGB`, `RGBA`, `RRGGBB` or `RRGGBBAA` (KaTeX #4090).
  static Color _hexColor(String hex) {
    final full = hex.length <= 4 ? hex.split('').map((c) => c * 2).join() : hex;
    final rgb = int.parse(full.substring(0, 6), radix: 16);
    final alpha =
        full.length == 8 ? int.parse(full.substring(6), radix: 16) : 0xff;
    return Color((alpha << 24) | rgb);
  }

  static final _parseSizeRegex =
      RegExp(r'^[-+]? *(?:$|\d+|\d+\.\d*|\.\d*) *[a-z]{0,2} *$');
  static final _parseMeasurementRegex =
      RegExp(r'([-+]?) *(\d+(?:\.\d*)?|\.\d+) *([a-z]{2})');

  /// KaTeX: parseSizeGroup. Returns null for an absent optional argument,
  /// and for a blank required argument (KaTeX: isBlank, which \genfrac
  /// reads as "default thickness" and \above as 0pt).
  Measurement? parseArgSize({required bool optional}) {
    currArgParsingContext.newArgument(optional: optional);
    _returnFetchedToken();
    macroExpander.consumeSpaces();
    Token? res;
    if (!optional && macroExpander.future().text != '{') {
      res = _parseRegexGroup(_parseSizeRegex, 'size');
    } else {
      res = _parseStringGroup(optional: optional);
    }
    if (res == null) {
      _assertOptionalBeforeReturn(null, optional: optional);
      return null;
    }
    if (!optional && res.text.isEmpty) {
      return null;
    }
    final match = _parseMeasurementRegex.firstMatch(res.text);
    if (match == null) {
      throw ParseException("Invalid size: '${res.text}'", res);
    }
    final unit = match[3]!.parseUnit();
    if (unit == null) {
      throw ParseException("Invalid unit: '${match[3]}'", res);
    }
    return Measurement(value: double.parse(match[1]! + match[2]!), unit: unit);
  }

  String parseArgUrl({required bool optional}) {
    currArgParsingContext.newArgument(optional: optional);
    // ADR 001 NG3: \href and \url are not supported.
    throw UnimplementedError();
  }

  /// Parses an argument as math or text (KaTeX argTypes "math", "text",
  /// "original", "primitive"). Returns a row, or a single node for a
  /// primitive argument without braces.
  GreenNode? parseArgNode({required Mode? mode, required bool optional}) {
    currArgParsingContext.newArgument(optional: optional);
    final funcData = currArgParsingContext.funcData;
    if (!optional && (funcData.primitive || funcData.primitiveArg)) {
      return parseArgPrimitive();
    }
    _returnFetchedToken();
    final res = _parseArgumentGroup(optional: optional, mode: mode);
    _assertOptionalBeforeReturn(res, optional: optional);
    return res;
  }

  /// KaTeX argType "primitive": a group, not a macro argument. \sqrt reads
  /// its body like this when it has no index.
  GreenNode parseArgPrimitive() {
    final name = currArgParsingContext.name;
    final group = parseGroup(name);
    if (group == null) {
      throw ParseException('Expected group as $name', fetch());
    }
    return group;
  }

  /// KaTeX: parseArgumentGroup.
  EquationRowNode? _parseArgumentGroup({required bool optional, Mode? mode}) {
    final argToken = macroExpander.scanArgument(isOptional: optional);
    if (argToken == null) return null;
    final outerMode = this.mode;
    if (mode != null) switchMode(mode);
    macroExpander.beginGroup();
    final expression =
        parseExpression(breakOnInfix: false, breakOnTokenText: 'EOF');
    expect('EOF');
    macroExpander.endGroup();
    if (mode != null) switchMode(outerMode);
    return expression.wrapWithEquationRow();
  }

  GreenNode parseArgHbox({required bool optional}) {
    final res = parseArgNode(mode: Mode.text, optional: optional);
    if (res is EquationRowNode) {
      return EquationRowNode(children: [
        StyleNode(
          optionsDiff: OptionsDiff(style: MathStyle.text),
          children: res.children,
        )
      ]);
    } else {
      return StyleNode(
        optionsDiff: OptionsDiff(style: MathStyle.text),
        children: res?.children.nonNulls.toList(growable: false) ?? [],
      );
    }
  }

  /// KaTeX argType "raw": the argument text, unexpanded by the parser,
  /// with `%` as a normal character (#4307).
  String? parseArgRaw({required bool optional}) {
    currArgParsingContext.newArgument(optional: optional);
    _returnFetchedToken();
    macroExpander.consumeSpaces();
    final catCodes = macroExpander.lexer.catCodes;
    final percent = catCodes['%'];
    catCodes['%'] = 12; // other character
    try {
      return _parseStringGroup(optional: optional)?.text;
    } finally {
      if (percent == null) {
        catCodes.remove('%');
      } else {
        catCodes['%'] = percent;
      }
    }
  }

  void _assertOptionalBeforeReturn(Object? value, {required bool optional}) {
    if (!optional && value == null) {
      throw ParseException(
          'Expected group after ${currArgParsingContext.funcName}', fetch());
    }
  }

  /// KaTeX: parseStringGroup. The argument tokens, expanded, as one string.
  Token? _parseStringGroup({required bool optional}) {
    final argToken = macroExpander.scanArgument(isOptional: optional);
    if (argToken == null) return null;
    final str = StringBuffer();
    Token next;
    while ((next = fetch()).text != 'EOF') {
      str.write(next.text);
      consume();
    }
    consume(); // the end of the argument
    return Token(str.toString(), argToken.loc);
  }

  /// KaTeX: parseRegexGroup.
  Token _parseRegexGroup(RegExp regex, String modeName) {
    final firstToken = fetch();
    var lastToken = firstToken;
    var str = '';
    Token nextToken;
    while ((nextToken = fetch()).text != 'EOF' &&
        regex.hasMatch(str + nextToken.text)) {
      lastToken = nextToken;
      str += lastToken.text;
      consume();
    }
    if (str.isEmpty) {
      throw ParseException(
          "Invalid $modeName: '${firstToken.text}'", firstToken);
    }
    return Token.range(firstToken, lastToken, str);
  }

  /// The operand of a Dart operator node (`\sin x`, `\sum_i x`,
  /// `\operatorname{f} x`). KaTeX has no operand: the next atom simply
  /// follows. Line breaks, infix commands, and the end of a group are not
  /// operands.
  GreenNode? parseOperand(String? breakOnTokenText) {
    consumeSpaces();
    final token = fetch();
    final text = token.text;
    if (endOfExpression.contains(text) ||
        text == breakOnTokenText ||
        text == 'EOF' ||
        text == '\\cr' ||
        text == '\\newline' ||
        functions[text]?.infix == true) {
      return null;
    }
    final atom = parseAtom(breakOnTokenText);
    return atom is InternalNode ? null : atom;
  }

  static final _parseVerbRegex = RegExp(r'^\\verb[^a-zA-Z]');

  GreenNode? _parseSymbol() {
    final nucleus = fetch();
    var text = nucleus.text;
    if (_parseVerbRegex.hasMatch(text)) {
      consume();
      var arg = text.substring(5);
      final star = (arg[0] == '*'); //?
      if (star) {
        arg = arg.substring(1);
      }
      // Lexer's tokenRegex is constructed to always have matching
      // first/last characters.

      if (arg.length < 2 || arg[0] != arg[arg.length - 1]) {
        throw ParseException('''\\verb assertion failed --
                    please report what input caused this bug''');
      }
      arg = arg.substring(1, arg.length - 1);
      return EquationRowNode(
        children: arg
            .split('')
            .map((char) => SymbolNode(
                  symbol: char,
                  overrideFont: const FontOptions(fontFamily: 'Typewriter'),
                  mode: Mode.text,
                ))
            .toList(growable: false),
      );
    }
    // At this point, we should have a symbol, possibly with accents.
    // First expand any accented base symbol according to unicodeSymbols.
    if (unicodeSymbols.containsKey(text[0]) &&
        !texSymbolCommandConfigs[mode]!.containsKey(text[0])) {
      if (mode == Mode.math) {
        settings.reportNonstrict(
            'unicodeTextInMathMode',
            'Accented Unicode text character "${text[0]}" used in math mode',
            nucleus);
      }
      // text = unicodeSymbols[text[0]] + text.substring(1);
    }
    // Strip off any combining characters
    final match = combiningDiacriticalMarksEndRegex.firstMatch(text);
    var combiningMarks = '';
    if (match != null) {
      text = text.substring(0, match.start);
      for (var i = 0; i < match[0]!.length; i++) {
        final accent = match[0]![i];
        if (!unicodeAccents.containsKey(accent)) {
          throw ParseException("Unknown accent ' $accent'", nucleus);
        }
        final command = unicodeAccents[accent]![mode];
        if (command == null) {
          throw ParseException(
              'Accent $accent unsupported in $mode mode', nucleus);
        }
      }
      combiningMarks = match[0]!;
    }
    // Recognize base symbol
    GreenNode symbol;
    final symbolCommandConfig = texSymbolCommandConfigs[mode]![text];
    if (symbolCommandConfig != null) {
      if (mode == Mode.math && extraLatin.contains(text)) {
        settings.reportNonstrict(
            'unicodeTextInMathMode',
            'Latin-1/Unicode text character "${text[0]}" used in math mode',
            nucleus);
      }
      // final loc = SourceLocation.range(nucleus);
      symbol = SymbolNode(
        mode: mode,
        symbol: symbolCommandConfig.symbol + combiningMarks,
        variantForm: symbolCommandConfig.variantForm,
        overrideAtomType: symbolCommandConfig.type,
        overrideFont: symbolCommandConfig.font,
      );
    } else if (text.isNotEmpty && text.codeUnitAt(0) >= 0x80) {
      if (!supportedCodepoint(text.codeUnitAt(0))) {
        settings.reportNonstrict(
            'unknownSymbol',
            'Unrecognized Unicode character "${text[0]}" '
                '(${text.codeUnitAt(0)})',
            nucleus);
      } else if (mode == Mode.math) {
        settings.reportNonstrict('unicodeTextInMathMode',
            'Unicode text character "${text[0]} used in math mode"', nucleus);
      }
      symbol = SymbolNode(
          symbol: text + combiningMarks,
          overrideAtomType: AtomType.ord,
          mode: mode);
    } else {
      return null;
    }
    consume();
    return symbol;
  }

  void switchMode(Mode newMode) {
    mode = newMode;
    macroExpander.mode = newMode;
  }

  GreenNode _formatUnsuppotedCmd(String text) {
    //TODO
    throw UnimplementedError();
  }
}

class ArgumentParsingContext {
  final String funcName;
  int currArgNum;
  final FunctionSpec funcData;

  bool get optional => _optional;
  bool _optional;

  set optional(bool value) {
    assert(_optional || !value);
    _optional = value;
  }

  String get name => "argument to '$funcName'";

  ArgumentParsingContext({
    required this.funcData,
    required this.funcName,
    this.currArgNum = -1,
    bool optional = true,
  }) : _optional = optional;

  void newArgument({required bool optional}) {
    currArgNum++;
    this.optional = optional;
  }
}

class ScriptsParsingResults {
  final EquationRowNode? subscript;
  final EquationRowNode? superscript;
  final bool? limits;

  const ScriptsParsingResults({
    required this.subscript,
    required this.superscript,
    this.limits,
  });

  bool get empty => subscript == null && superscript == null;
}

T assertNodeType<T extends GreenNode?>(GreenNode? node) {
  if (node is T) {
    return node;
  }
  throw ParseException(
      'Expected node of type $T, but got node of type ${node.runtimeType}');
}
