// katex-sync: src/functions/relax.ts @ v0.19.1
part of '../katex_base.dart';

const _relaxEntries = {
  ['\\relax']: FunctionSpec(
    numArgs: 0,
    allowedInText: true,
    allowedInArgument: true,
    primitive: true,
    handler: _relaxHandler,
  ),
};

/// KaTeX: an "internal" parse node. The parser drops it.
class InternalNode extends TemporaryNode {}

GreenNode _relaxHandler(TexParser parser, FunctionContext context) =>
    InternalNode();
