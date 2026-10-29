import '../../render/layout/shift_baseline.dart';
import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';

/// Centers its body on the math axis.
///
/// Example: `\vcenter{\frac a b}`
class VCenterNode extends SlotableNode<EquationRowNode> {
  final EquationRowNode body;

  VCenterNode({required this.body});

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) =>
      BuildResult(
        options: options,
        // KaTeX vcenter.ts: the box's middle is at the axis.
        widget: ShiftBaseline(
          relativePos: 0.5,
          offset: options.fontMetrics.axisHeight.cssEm.toLpUnder(options),
          child: childBuildResults[0]!.widget,
        ),
      );

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
      oldOptions.sizeMultiplier != newOptions.sizeMultiplier;

  @override
  VCenterNode updateChildren(List<EquationRowNode> newChildren) =>
      VCenterNode(body: newChildren[0]);

  @override
  Map<String, Object?> toJson() =>
      super.toJson()..addAll({'body': body.toJson()});
}
