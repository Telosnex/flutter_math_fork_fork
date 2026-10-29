import '../options.dart';
import '../style.dart';
import '../syntax_tree.dart';

/// Shows one of four bodies, chosen by the current style.
///
/// Example: `\mathchoice{D}{T}{S}{SS}`
class MathChoiceNode extends SlotableNode<EquationRowNode> {
  final EquationRowNode display;
  final EquationRowNode text;
  final EquationRowNode script;
  final EquationRowNode scriptScript;

  MathChoiceNode({
    required this.display,
    required this.text,
    required this.script,
    required this.scriptScript,
  });

  @override
  BuildResult buildWidget(
    MathOptions options,
    List<BuildResult?> childBuildResults,
  ) =>
      BuildResult(
        options: options,
        widget: childBuildResults[options.style.size]!.widget,
      );

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      List.filled(4, options);

  @override
  List<EquationRowNode> computeChildren() =>
      [display, text, script, scriptScript];

  @override
  AtomType get leftType => AtomType.ord;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      oldOptions.style.size != newOptions.style.size;

  @override
  MathChoiceNode updateChildren(List<EquationRowNode> newChildren) =>
      MathChoiceNode(
        display: newChildren[0],
        text: newChildren[1],
        script: newChildren[2],
        scriptScript: newChildren[3],
      );

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'display': display.toJson(),
      'text': text.toJson(),
      'script': script.toJson(),
      'scriptScript': scriptScript.toJson(),
    });
}
