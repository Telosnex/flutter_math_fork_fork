// katex-sync: src/functions/def.ts @ v0.19.1
part of '../katex_base.dart';

// Flags (primitive, allowedInText) come from katex_function_flags.dart.
const _defEntries = {
  ['\\global', '\\long', '\\\\globallong']:
      FunctionSpec(numArgs: 0, handler: _prefixHandler),
  ['\\def', '\\gdef', '\\edef', '\\xdef']:
      FunctionSpec(numArgs: 0, handler: _defHandler),
  ['\\let', '\\\\globallet']: FunctionSpec(numArgs: 0, handler: _letHandler),
  ['\\futurelet', '\\\\globalfuture']:
      FunctionSpec(numArgs: 0, handler: _futureletHandler),
};

const _globalMap = {
  '\\global': '\\global',
  '\\long': '\\\\globallong',
  '\\\\globallong': '\\\\globallong',
  '\\def': '\\gdef',
  '\\gdef': '\\gdef',
  '\\edef': '\\xdef',
  '\\xdef': '\\xdef',
  '\\let': '\\\\globallet',
  '\\futurelet': '\\\\globalfuture',
};

final _notControlSequence = RegExp(r'^(?:[\\{}$&#^_]|EOF)$');
final _argNumber = RegExp(r'^[1-9]$');

String _checkControlSequence(Token tok) {
  if (_notControlSequence.hasMatch(tok.text)) {
    throw ParseException('Expected a control sequence', tok);
  }
  return tok.text;
}

/// `<equals>`: an optional `=` and then one optional space.
Token _getRHS(TexParser parser) {
  final gullet = parser.macroExpander;
  var tok = gullet.popToken();
  if (tok.text == '=') {
    tok = gullet.popToken();
    if (tok.text == ' ') {
      tok = gullet.popToken();
    }
  }
  return tok;
}

void _letCommand(
  TexParser parser,
  String name,
  Token tok, {
  required bool global,
}) {
  final gullet = parser.macroExpander;
  var macro = gullet.macros.get(tok.text);
  if (macro == null) {
    // Don't expand it later even if a macro with the same name is defined,
    // e.g., \let\foo=\frac \def\frac{\relax} \frac12
    tok.noexpand = true;
    macro = MacroDefinition.fromMacroExpansion(MacroExpansion(
      tokens: [tok],
      numArgs: 0,
      // reproduce the same behavior in expansion
      unexpandable: !gullet.isExpandable(tok.text),
    ));
  }
  gullet.macros.set(name, macro, global: global);
}

// <assignment> -> <non-macro assignment>|<macro assignment>
// <prefix> -> \global|\long|\outer
GreenNode _prefixHandler(TexParser parser, FunctionContext context) {
  parser.consumeSpaces();
  final token = parser.fetch();
  final mapped = _globalMap[token.text];
  if (mapped != null) {
    // KaTeX doesn't have \par, so ignore \long
    if (context.funcName == '\\global' ||
        context.funcName == '\\\\globallong') {
      token.text = mapped;
    }
    final result = parser.parseFunction(context.breakOnTokenText, null);
    if (result is! InternalNode) {
      throw ParseException('Invalid token after macro prefix', token);
    }
    return result;
  }
  throw ParseException('Invalid token after macro prefix', token);
}

// <definition> -> <def><control sequence><definition text>
// <definition text> -> <parameter text><left brace><balanced text><right brace>
GreenNode _defHandler(TexParser parser, FunctionContext context) {
  final gullet = parser.macroExpander;
  var tok = gullet.popToken();
  final name = tok.text;
  if (_notControlSequence.hasMatch(name)) {
    throw ParseException('Expected a control sequence', tok);
  }

  var numArgs = 0;
  Token? insert;
  final delimiters = <List<String>>[[]];
  // <parameter text> contains no braces
  while (gullet.future().text != '{') {
    tok = gullet.popToken();
    if (tok.text == '#') {
      // If the very last character of the <parameter text> is #, so that
      // this # is immediately followed by {, TeX will behave as if the {
      // had been inserted at the right end of both the parameter text and
      // the replacement text.
      if (gullet.future().text == '{') {
        insert = gullet.future();
        delimiters[numArgs].add('{');
        break;
      }
      // A parameter: the first # must be followed by 1, the next by 2, and
      // so on; up to nine #'s are allowed.
      tok = gullet.popToken();
      if (!_argNumber.hasMatch(tok.text)) {
        throw ParseException('Invalid argument number "${tok.text}"');
      }
      if (int.parse(tok.text) != numArgs + 1) {
        throw ParseException('Argument number "${tok.text}" out of order');
      }
      numArgs++;
      delimiters.add([]);
    } else if (tok.text == 'EOF') {
      throw ParseException('Expected a macro definition');
    } else {
      delimiters[numArgs].add(tok.text);
    }
  }

  // replacement text, enclosed in '{' and '}' and properly nested
  var tokens = gullet.consumeArg().tokens;
  if (insert != null) {
    tokens.insert(0, insert); // stack order: the end of the expansion
  }
  if (context.funcName == '\\edef' || context.funcName == '\\xdef') {
    tokens = gullet.expandTokens(tokens).reversed.toList();
  }
  gullet.macros.set(
    name,
    MacroDefinition.fromMacroExpansion(MacroExpansion(
      tokens: tokens,
      numArgs: numArgs,
      delimiters: delimiters,
    )),
    global: context.funcName == _globalMap[context.funcName],
  );
  return InternalNode();
}

// <let assignment> -> \let<control sequence><equals><one optional space><token>
GreenNode _letHandler(TexParser parser, FunctionContext context) {
  final gullet = parser.macroExpander;
  final name = _checkControlSequence(gullet.popToken());
  gullet.consumeSpaces();
  final tok = _getRHS(parser);
  _letCommand(parser, name, tok, global: context.funcName == '\\\\globallet');
  return InternalNode();
}

// \futurelet<control sequence><token><token>
// ref: https://www.tug.org/TUGboat/tb09-3/tb22bechtolsheim.pdf
GreenNode _futureletHandler(TexParser parser, FunctionContext context) {
  final gullet = parser.macroExpander;
  final name = _checkControlSequence(gullet.popToken());
  final middle = gullet.popToken();
  final tok = gullet.popToken();
  _letCommand(parser, name, tok,
      global: context.funcName == '\\\\globalfuture');
  gullet
    ..pushToken(tok)
    ..pushToken(middle);
  return InternalNode();
}
