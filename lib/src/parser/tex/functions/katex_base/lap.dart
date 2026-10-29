// katex-sync: src/functions/lap.ts @ v0.19.1
part of '../katex_base.dart';

// Horizontal overlap functions
const _lapEntries = {
  ['\\mathllap', '\\mathrlap', '\\mathclap']: FunctionSpec(
    numArgs: 1,
    handler: _lapHandler,
  ),
};

GreenNode _lapHandler(TexParser parser, FunctionContext context) {
  final body = parser.parseArgNode(mode: null, optional: false)!;
  return LapNode(
    body: body.wrapWithEquationRow(),
    alignment: switch (context.funcName) {
      '\\mathllap' => LapAlignment.left,
      '\\mathrlap' => LapAlignment.right,
      _ => LapAlignment.center,
    },
  );
}
