import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';

/// "Poor man's bold": the body painted twice, the second copy shifted by
/// (0.02em, 0.01em), as KaTeX's CSS text-shadow.
///
/// Example: `\pmb`
class PmbNode extends SlotableNode<EquationRowNode> {
  final EquationRowNode body;

  /// The atom type, from the body (KaTeX: binrelClass).
  final AtomType atomType;

  PmbNode({required this.body, this.atomType = AtomType.ord});

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) =>
      BuildResult(
        options: options,
        widget: _PaintTwice(
          shift: Offset(
            0.02.cssEm.toLpUnder(options),
            0.01.cssEm.toLpUnder(options),
          ),
          child: childBuildResults[0]!.widget,
        ),
      );

  @override
  List<MathOptions> computeChildOptions(MathOptions options) => [options];

  @override
  List<EquationRowNode> computeChildren() => [body];

  @override
  AtomType get leftType => atomType;

  @override
  AtomType get rightType => atomType;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  PmbNode updateChildren(List<EquationRowNode> newChildren) =>
      PmbNode(body: newChildren[0], atomType: atomType);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({'body': body.toJson(), 'atomType': atomType.name});
}

class _PaintTwice extends SingleChildRenderObjectWidget {
  const _PaintTwice({required this.shift, super.child});

  final Offset shift;

  @override
  _RenderPaintTwice createRenderObject(BuildContext context) =>
      _RenderPaintTwice(shift);

  @override
  void updateRenderObject(
      BuildContext context, _RenderPaintTwice renderObject) {
    renderObject.shift = shift;
  }
}

class _RenderPaintTwice extends RenderProxyBox {
  _RenderPaintTwice(this._shift);

  Offset _shift;
  Offset get shift => _shift;
  set shift(Offset value) {
    if (value == _shift) return;
    _shift = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context
      ..paintChild(child, offset + _shift)
      ..paintChild(child, offset);
  }
}
