// katex-sync: src/functions/htmlmathml.ts @ v0.19.1
// katex-sync: src/functions/reflectbox.ts @ v0.19.1
// katex-sync: src/functions/mathchoice.ts @ v0.19.1
// katex-sync: src/functions/pmb.ts @ v0.19.1
// katex-sync: src/functions/hbox.ts @ v0.19.1
// katex-sync: src/functions/vcenter.ts @ v0.19.1
part of '../katex_base.dart';

// Flags come from katex_function_flags.dart.
const _miscV0191Entries = {
  ['\\html@mathml']: FunctionSpec(numArgs: 2, handler: _htmlMathmlHandler),
  ['\\@binrel']: FunctionSpec(numArgs: 2, handler: _binrelHandler),
  ['\\reflectbox']: FunctionSpec(numArgs: 1, handler: _reflectBoxHandler),
  ['\\mathreflectbox']:
      FunctionSpec(numArgs: 1, handler: _mathReflectBoxHandler),
  ['\\mathchoice']: FunctionSpec(numArgs: 4, handler: _mathChoiceHandler),
  ['\\pmb']: FunctionSpec(numArgs: 1, handler: _pmbHandler),
  ['\\hbox']: FunctionSpec(numArgs: 1, handler: _hboxHandler),
  ['\\vcenter']: FunctionSpec(numArgs: 1, handler: _vcenterHandler),
  ['\\angl', '\\phase']: FunctionSpec(numArgs: 1, handler: _angleHandler),
};

GreenNode _vcenterHandler(TexParser parser, FunctionContext context) =>
    VCenterNode(
      body: parser
          .parseArgNode(mode: null, optional: false)!
          .wrapWithEquationRow(),
    );

GreenNode _angleHandler(TexParser parser, FunctionContext context) =>
    AngleEncloseNode(
      body: parser
          .parseArgNode(mode: null, optional: false)!
          .wrapWithEquationRow(),
      kind: context.funcName == '\\angl'
          ? AngleEncloseKind.angl
          : AngleEncloseKind.phase,
    );

/// The HTML branch. Dart builds no MathML.
GreenNode _htmlMathmlHandler(TexParser parser, FunctionContext context) {
  final html = parser.parseArgNode(mode: null, optional: false)!;
  parser.parseArgNode(mode: null, optional: false);
  return html.wrapWithEquationRow();
}

/// KaTeX mclass.ts binrelClass: bin or rel if the argument is one bin or
/// rel atom, else ord.
AtomType binrelClass(GreenNode arg) {
  final atom = arg is EquationRowNode && arg.children.length == 1
      ? arg.children.single
      : arg;
  final type = atom is EquationRowNode && atom.overrideType != null
      ? atom.overrideType!
      : atom.leftType;
  return type == AtomType.bin || type == AtomType.rel ? type : AtomType.ord;
}

// \@binrel{x}{y} renders like y but as mbin/mrel/mord if x is mbin/mrel/mord.
GreenNode _binrelHandler(TexParser parser, FunctionContext context) {
  final x = parser.parseArgNode(mode: null, optional: false)!;
  final y = parser.parseArgNode(mode: null, optional: false)!;
  return EquationRowNode(
    children: y.expandEquationRow(),
    overrideType: binrelClass(x),
  );
}

GreenNode _reflectBoxHandler(TexParser parser, FunctionContext context) =>
    ReflectBoxNode(
      body: parser.parseArgHbox(optional: false).wrapWithEquationRow(),
    );

GreenNode _mathReflectBoxHandler(TexParser parser, FunctionContext context) =>
    ReflectBoxNode(
      body: parser
          .parseArgNode(mode: Mode.math, optional: false)!
          .wrapWithEquationRow(),
    );

GreenNode _mathChoiceHandler(TexParser parser, FunctionContext context) {
  EquationRowNode arg() => parser.parseArgPrimitive().wrapWithEquationRow();
  return MathChoiceNode(
    display: arg(),
    text: arg(),
    script: arg(),
    scriptScript: arg(),
  );
}

GreenNode _pmbHandler(TexParser parser, FunctionContext context) {
  final body = parser.parseArgNode(mode: null, optional: false)!;
  return PmbNode(
    body: body.wrapWithEquationRow(),
    atomType: binrelClass(body),
  );
}

// \hbox: text mode, text style.
GreenNode _hboxHandler(TexParser parser, FunctionContext context) =>
    parser.parseArgHbox(optional: false);
