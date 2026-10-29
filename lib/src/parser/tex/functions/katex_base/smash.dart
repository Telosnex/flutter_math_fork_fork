// katex-sync: src/functions/smash.ts @ v0.19.1
part of '../katex_base.dart';

const _smashEntries = {
  ['\\smash']: FunctionSpec(
    numArgs: 1,
    numOptionalArgs: 1,
    handler: _smashHandler,
  ),
};

// smash, with optional [tb], as in AMS
GreenNode _smashHandler(TexParser parser, FunctionContext context) {
  final tbArg = parser.parseArgNode(mode: null, optional: true);
  var smashHeight = false;
  var smashDepth = false;
  if (tbArg != null) {
    // ref: amsmath: \renewcommand{\smash}[1][tb]{%
    //   def\mb@t{\ht}\def\mb@b{\dp}\def\mb@tb{\ht\z@\z@\dp}%
    for (final node in tbArg.children) {
      if (node is! SymbolNode) {
        throw ParseException('Expected node of symbol group type, but got '
            '${node.runtimeType}');
      }
      if (node.symbol == 't') {
        smashHeight = true;
      } else if (node.symbol == 'b') {
        smashDepth = true;
      } else {
        smashHeight = false;
        smashDepth = false;
        break;
      }
    }
  } else {
    smashHeight = true;
    smashDepth = true;
  }
  final body = parser.parseArgNode(mode: null, optional: false)!;
  return SmashNode(
    body: body.wrapWithEquationRow(),
    smashHeight: smashHeight,
    smashDepth: smashDepth,
  );
}
