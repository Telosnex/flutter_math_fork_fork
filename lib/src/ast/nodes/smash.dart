import '../../render/layout/reset_dimension.dart';
import '../options.dart';
import '../syntax_tree.dart';

/// Hides the height and/or depth of its body from the layout. The body is
/// still painted.
///
/// Example: `\smash`, `\smash[t]`, `\smash[b]`
class SmashNode extends SlotableNode<EquationRowNode> {
  final EquationRowNode body;

  /// Whether the layout height (above the baseline) is zero.
  final bool smashHeight;

  /// Whether the layout depth (below the baseline) is zero.
  final bool smashDepth;

  SmashNode({
    required this.body,
    this.smashHeight = true,
    this.smashDepth = true,
  });

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) =>
      BuildResult(
        options: options,
        widget: ResetDimension(
          height: smashHeight ? 0 : null,
          depth: smashDepth ? 0 : null,
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
      false;

  @override
  SmashNode updateChildren(List<EquationRowNode> newChildren) => SmashNode(
        body: newChildren[0],
        smashHeight: smashHeight,
        smashDepth: smashDepth,
      );

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'body': body.toJson(),
      if (!smashHeight) 'smashHeight': smashHeight,
      if (!smashDepth) 'smashDepth': smashDepth,
    });
}
