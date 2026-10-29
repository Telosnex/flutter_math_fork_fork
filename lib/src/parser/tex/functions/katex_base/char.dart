// katex-sync: src/functions/char.ts @ v0.19.1
part of '../katex_base.dart';

const _charEntries = {
  ['\\@char']:
      FunctionSpec(numArgs: 1, allowedInText: true, handler: _charHandler),
};

/// KaTeX assertCharacterGroup: the characters of a group of plain
/// symbols. A symbol from `\text` in math mode is not plain.
String assertCharacterGroup(TexParser parser, GreenNode? arg, String message) {
  final children = arg is EquationRowNode ? arg.children : [arg];
  return children.map((child) {
    if (child is SymbolNode && child.mode == parser.mode) return child.symbol;
    throw ParseException(message);
  }).join();
}

GreenNode _charHandler(TexParser parser, FunctionContext context) {
  final number = assertCharacterGroup(
    parser,
    parser.parseArgNode(mode: null, optional: false),
    '\\@char has non-numeric argument',
  );
  final code = int.tryParse(number);
  if (code == null) {
    throw ParseException('\\@char has non-numeric argument $number');
  } else if (code < 0 || code > 0x10ffff) {
    throw ParseException('\\@char with invalid code point $number');
  }
  return SymbolNode(
    symbol: String.fromCharCode(code),
    mode: parser.mode,
    overrideAtomType: AtomType.ord,
  );
}
