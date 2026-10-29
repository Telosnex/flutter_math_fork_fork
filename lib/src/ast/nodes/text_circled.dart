import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';
import '../types.dart';
import 'symbol.dart';

/// Draws a big circle (U+25EF) over its body, as KaTeX's "full" accent.
/// Both are centered horizontally. The circle's baseline is 0.2em below
/// the body's baseline.
///
/// Example: `\textcircled{c}`, and so `©`, `®`
class TextCircledNode extends SlotableNode<EquationRowNode> {
  final EquationRowNode body;

  TextCircledNode({required this.body});

  /// One per node: a node cannot have two parents.
  late final _circle = EquationRowNode(
    children: [SymbolNode(symbol: '\u25EF', mode: Mode.text)],
  );

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) =>
      BuildResult(
        options: options,
        widget: _CenterOnBaseline(
          circleDrop: 0.2.cssEm.toLpUnder(options),
          children: [
            childBuildResults[0]!.widget,
            childBuildResults[1]!.widget,
          ],
        ),
      );

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      [options, options];

  @override
  List<EquationRowNode> computeChildren() => [body, _circle];

  @override
  AtomType get leftType => AtomType.ord;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      oldOptions.sizeMultiplier != newOptions.sizeMultiplier;

  @override
  TextCircledNode updateChildren(List<EquationRowNode> newChildren) =>
      TextCircledNode(body: newChildren[0]);

  @override
  Map<String, Object?> toJson() =>
      super.toJson()..addAll({'body': body.toJson()});
}

class _CenterOnBaseline extends MultiChildRenderObjectWidget {
  const _CenterOnBaseline({required this.circleDrop, super.children});

  final double circleDrop;

  @override
  _RenderCenterOnBaseline createRenderObject(BuildContext context) =>
      _RenderCenterOnBaseline(circleDrop);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCenterOnBaseline renderObject,
  ) {
    renderObject.circleDrop = circleDrop;
  }
}

class _Data extends ContainerBoxParentData<RenderBox> {}

/// Two children: the body, then the circle.
class _RenderCenterOnBaseline extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _Data>,
        RenderBoxContainerDefaultsMixin<RenderBox, _Data> {
  _RenderCenterOnBaseline(this._circleDrop);

  double _circleDrop;
  double get circleDrop => _circleDrop;
  set circleDrop(double value) {
    if (value == _circleDrop) return;
    _circleDrop = value;
    markNeedsLayout();
  }

  double _baseline = 0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Data) child.parentData = _Data();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  @override
  void performLayout() {
    final body = firstChild!;
    final circle = childAfter(body)!;
    const loose = BoxConstraints();
    body.layout(loose, parentUsesSize: true);
    circle.layout(loose, parentUsesSize: true);
    final bodyBase =
        body.getDistanceToBaseline(TextBaseline.alphabetic) ?? body.size.height;
    final circleBase = (circle.getDistanceToBaseline(TextBaseline.alphabetic) ??
            circle.size.height) -
        circleDrop;
    _baseline = bodyBase > circleBase ? bodyBase : circleBase;
    final width = body.size.width > circle.size.width
        ? body.size.width
        : circle.size.width;
    final bodyDepth = body.size.height - bodyBase;
    final circleDepth = circle.size.height - circleBase;
    final depth = bodyDepth > circleDepth ? bodyDepth : circleDepth;
    (body.parentData! as _Data).offset =
        Offset((width - body.size.width) / 2, _baseline - bodyBase);
    (circle.parentData! as _Data).offset =
        Offset((width - circle.size.width) / 2, _baseline - circleBase);
    size = constraints.constrain(Size(width, _baseline + depth));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
