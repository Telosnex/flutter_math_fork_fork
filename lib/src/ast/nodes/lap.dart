import 'package:flutter/widgets.dart';

import '../../render/layout/reset_dimension.dart';
import '../options.dart';
import '../syntax_tree.dart';

/// Where a [LapNode] puts its body.
enum LapAlignment {
  /// `\mathllap`: the body ends at the node, overlapping what is before.
  left,

  /// `\mathrlap`: the body starts at the node, overlapping what is after.
  right,

  /// `\mathclap`: the body is centered on the node.
  center,
}

/// Gives its body zero width, so that the body overlaps its neighbors.
///
/// Example: `\mathllap`, `\mathrlap`, `\mathclap`
class LapNode extends SlotableNode<EquationRowNode> {
  final EquationRowNode body;
  final LapAlignment alignment;

  LapNode({required this.body, required this.alignment});

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) =>
      BuildResult(
        options: options,
        widget: ResetDimension(
          width: 0,
          horizontalAlignment: switch (alignment) {
            LapAlignment.left => CrossAxisAlignment.end,
            LapAlignment.right => CrossAxisAlignment.start,
            LapAlignment.center => CrossAxisAlignment.center,
          },
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
  LapNode updateChildren(List<EquationRowNode> newChildren) =>
      LapNode(body: newChildren[0], alignment: alignment);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({'body': body.toJson(), 'alignment': alignment.name});
}
