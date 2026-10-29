import 'package:flutter/widgets.dart';

import '../options.dart';
import '../syntax_tree.dart';

/// Mirrors its body left to right.
///
/// Example: `\reflectbox`, `\mathreflectbox`
class ReflectBoxNode extends SlotableNode<EquationRowNode> {
  final EquationRowNode body;

  ReflectBoxNode({required this.body});

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) =>
      BuildResult(
        options: options,
        widget: Transform.flip(
          flipX: true,
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
  ReflectBoxNode updateChildren(List<EquationRowNode> newChildren) =>
      ReflectBoxNode(body: newChildren[0]);

  @override
  Map<String, Object?> toJson() =>
      super.toJson()..addAll({'body': body.toJson()});
}
