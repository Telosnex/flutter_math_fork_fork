import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';

enum AngleEncloseKind {
  /// `\angl`: the actuarial angle, a line above and right of the body.
  angl,

  /// `\phase`: the phasor angle, a slanted line left and a line below.
  phase,
}

/// KaTeX src/functions/enclose.ts, labels "angl" and "phase".
///
/// Example: `\angl{n}`, `\phase{-78.2^\circ}`
class AngleEncloseNode extends SlotableNode<EquationRowNode> {
  final EquationRowNode body;
  final AngleEncloseKind kind;

  AngleEncloseNode({required this.body, required this.kind});

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) {
    final em = 1.0.cssEm.toLpUnder(options);
    final metrics = options.fontMetrics;
    final child = childBuildResults[0]!.widget;
    final widget = switch (kind) {
      AngleEncloseKind.angl => _AngleBox(
          kind: kind,
          color: options.color,
          em: em,
          rule: metrics.defaultRuleThickness * em,
          clearance: 0,
          lineWeight: 0,
          child: child,
        ),
      AngleEncloseKind.phase => _AngleBox(
          kind: kind,
          color: options.color,
          em: em,
          rule: 0,
          lineWeight: 0.6.pt.toLpUnder(options),
          clearance: 0.35 * metrics.xHeight * em,
          child: child,
        ),
    };
    return BuildResult(options: options, widget: widget);
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) => [options];

  @override
  List<EquationRowNode> computeChildren() => [body];

  @override
  AtomType get leftType => AtomType.ord;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      oldOptions.sizeMultiplier != newOptions.sizeMultiplier ||
      oldOptions.color != newOptions.color;

  @override
  AngleEncloseNode updateChildren(List<EquationRowNode> newChildren) =>
      AngleEncloseNode(body: newChildren[0], kind: kind);

  @override
  Map<String, Object?> toJson() =>
      super.toJson()..addAll({'body': body.toJson(), 'kind': kind.name});
}

class _AngleBox extends SingleChildRenderObjectWidget {
  const _AngleBox({
    required this.kind,
    required this.color,
    required this.em,
    required this.rule,
    required this.lineWeight,
    required this.clearance,
    super.child,
  });

  final AngleEncloseKind kind;
  final Color color;
  final double em;
  final double rule;
  final double lineWeight;
  final double clearance;

  @override
  _RenderAngleBox createRenderObject(BuildContext context) =>
      _RenderAngleBox()..config = this;

  @override
  void updateRenderObject(BuildContext context, _RenderAngleBox renderObject) {
    renderObject.config = this;
  }
}

class _RenderAngleBox extends RenderProxyBox {
  _AngleBox? _config;
  _AngleBox get config => _config!;
  set config(_AngleBox value) {
    _config = value;
    markNeedsLayout();
  }

  double _baseline = 0;
  Offset _childOffset = Offset.zero;
  double _childHeight = 0; // child height above its baseline
  double _childDepth = 0;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  @override
  Size computeDryLayout(BoxConstraints constraints) => Size.zero;

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(const BoxConstraints(), parentUsesSize: true);
    final childBase = child.getDistanceToBaseline(TextBaseline.alphabetic) ??
        child.size.height;
    _childHeight = childBase;
    _childDepth = child.size.height - childBase;
    final c = config;
    switch (c.kind) {
      case AngleEncloseKind.angl:
        // .anglpad: 0.03889em left and right. The line is 4 rules above
        // the body; the bottom reaches 0.25em below the baseline.
        final pad = 0.03889 * c.em;
        final topPad = 4 * c.rule;
        final depth = _childDepth > 0.25 * c.em ? _childDepth : 0.25 * c.em;
        _baseline = _childHeight + topPad;
        _childOffset = Offset(pad, topPad);
        size = constraints.constrain(
          Size(child.size.width + 2 * pad + c.rule, _baseline + depth),
        );
      case AngleEncloseKind.phase:
        final angleHeight =
            _childHeight + _childDepth + c.lineWeight + c.clearance;
        final leftPad = angleHeight / 2 + c.lineWeight;
        _baseline = _childHeight;
        _childOffset = Offset(leftPad, 0);
        size = constraints.constrain(Size(
          child.size.width + leftPad,
          _childHeight + _childDepth + c.lineWeight + c.clearance,
        ));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(child!, offset + _childOffset);
    final c = config;
    final canvas = context.canvas;
    final paint = Paint()..color = c.color;
    switch (c.kind) {
      case AngleEncloseKind.angl:
        final r = c.rule;
        final top = offset.dy + _childOffset.dy - 3 * r - r;
        canvas
          ..drawRect(Rect.fromLTWH(offset.dx, top, size.width, r), paint)
          ..drawRect(
              Rect.fromLTWH(offset.dx + size.width - r, top, r,
                  offset.dy + size.height - top),
              paint);
      case AngleEncloseKind.phase:
        // KaTeX svgGeometry.ts phasePath, in 1/1000 em, y down from the
        // top of the angle.
        final u = c.em / 1000;
        final y = size.height / u;
        final w = size.width / u;
        final path = ui.Path()
          ..moveTo(w, y)
          ..lineTo(0, y)
          ..lineTo(y / 2, 0)
          ..relativeLineTo(65, 45)
          ..lineTo(145, y - 80)
          ..lineTo(w, y - 80)
          ..close();
        canvas
          ..save()
          ..translate(offset.dx, offset.dy)
          ..scale(u)
          ..drawPath(path, paint)
          ..restore();
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: _childOffset,
        position: position,
        hitTest: (result, transformed) =>
            child!.hitTest(result, position: transformed),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(_childOffset.dx, _childOffset.dy, 0, 1);
}
