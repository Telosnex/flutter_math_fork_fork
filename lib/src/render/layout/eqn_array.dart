import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../ast/nodes/matrix.dart';
import '../constants.dart';
import '../utils/render_box_layout.dart';
import '../utils/render_box_offset.dart';
import 'line.dart';

class EqnArrayParentData extends ContainerBoxParentData<RenderBox> {}

class EqnArray extends MultiChildRenderObjectWidget {
  final double ruleThickness;
  final double jotSize;
  final double arrayskip;
  final List<MatrixSeparatorStyle> hlines;
  final List<double> rowSpacings;

  /// Whether the second half of [children] is a tag for each row.
  final bool hasTags;

  /// The space between the widest row and the tags.
  final double tagGap;

  const EqnArray({
    super.key,
    required this.ruleThickness,
    required this.jotSize,
    required this.arrayskip,
    required this.hlines,
    required this.rowSpacings,
    this.hasTags = false,
    this.tagGap = 0,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => RenderEqnArray(
        ruleThickness: ruleThickness,
        jotSize: jotSize,
        arrayskip: arrayskip,
        hlines: hlines,
        rowSpacings: rowSpacings,
        hasTags: hasTags,
        tagGap: tagGap,
      );

  @override
  void updateRenderObject(BuildContext context, RenderEqnArray renderObject) =>
      renderObject
        ..ruleThickness = ruleThickness
        ..jotSize = jotSize
        ..arrayskip = arrayskip
        ..hlines = hlines
        ..rowSpacings = rowSpacings
        ..hasTags = hasTags
        ..tagGap = tagGap;
}

class RenderEqnArray extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, EqnArrayParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EqnArrayParentData>,
        DebugOverflowIndicatorMixin {
  RenderEqnArray({
    List<RenderBox>? children,
    required double ruleThickness,
    required double jotSize,
    required double arrayskip,
    required List<MatrixSeparatorStyle> hlines,
    required List<double> rowSpacings,
    bool hasTags = false,
    double tagGap = 0,
  })  : _hasTags = hasTags,
        _tagGap = tagGap,
        _ruleThickness = ruleThickness,
        _jotSize = jotSize,
        _arrayskip = arrayskip,
        _hlines = hlines,
        _rowSpacings = rowSpacings {
    addAll(children);
  }

  double get ruleThickness => _ruleThickness;
  double _ruleThickness;
  set ruleThickness(double value) {
    if (_ruleThickness != value) {
      _ruleThickness = value;
      markNeedsLayout();
    }
  }

  double get jotSize => _jotSize;
  double _jotSize;
  set jotSize(double value) {
    if (_jotSize != value) {
      _jotSize = value;
      markNeedsLayout();
    }
  }

  double get arrayskip => _arrayskip;
  double _arrayskip;
  set arrayskip(double value) {
    if (_arrayskip != value) {
      _arrayskip = value;
      markNeedsLayout();
    }
  }

  List<MatrixSeparatorStyle> get hlines => _hlines;
  List<MatrixSeparatorStyle> _hlines;
  set hlines(List<MatrixSeparatorStyle> value) {
    if (_hlines != value) {
      _hlines = value;
      markNeedsLayout();
    }
  }

  List<double> get rowSpacings => _rowSpacings;
  List<double> _rowSpacings;
  set rowSpacings(List<double> value) {
    if (_rowSpacings != value) {
      _rowSpacings = value;
      markNeedsLayout();
    }
  }

  bool get hasTags => _hasTags;
  bool _hasTags;
  set hasTags(bool value) {
    if (_hasTags != value) {
      _hasTags = value;
      markNeedsLayout();
    }
  }

  double get tagGap => _tagGap;
  double _tagGap;
  set tagGap(double value) {
    if (_tagGap != value) {
      _tagGap = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! EqnArrayParentData) {
      child.parentData = EqnArrayParentData();
    }
  }

  List<double> hlinePos = [];

  double width = 0.0;

  @override
  double? computeDryBaseline(
          covariant BoxConstraints constraints, TextBaseline baseline) =>
      null;
  // RenderEqnArray does not report a baseline
  // (computeDistanceToActualBaseline is not overridden).

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _computeLayout(constraints);

  @override
  void performLayout() {
    size = _computeLayout(constraints, dry: false);
  }

  Size _computeLayout(
    BoxConstraints constraints, {
    bool dry = true,
  }) {
    final nonAligningSizes = <Size>[];
    final rowCount = hasTags ? childCount ~/ 2 : childCount;
    // First pass, calculate width for each column.
    var child = firstChild;
    var rowIndex = 0;
    var width = 0.0;
    final colWidths = <double>[];
    final sizeMap = <RenderBox, Size>{};
    while (child != null && rowIndex++ < rowCount) {
      var childSize = Size.zero;
      if (child is RenderLine) {
        child.alignColWidth = null;
        childSize = child.getLayoutSize(infiniteConstraint, dry: dry);
        final childColWidth = child.alignColWidth;
        if (childColWidth != null) {
          for (var i = 0; i < childColWidth.length; i++) {
            if (i >= colWidths.length) {
              colWidths.add(childColWidth[i]);
            } else {
              colWidths[i] = math.max(
                colWidths[i],
                childColWidth[i],
              );
            }
          }
        } else {
          nonAligningSizes.add(childSize);
        }
      } else {
        childSize = child.getLayoutSize(infiniteConstraint, dry: dry);
        colWidths[0] = math.max(
          colWidths[0],
          childSize.width,
        );
      }
      sizeMap[child] = childSize;
      child = (child.parentData as EqnArrayParentData).nextSibling;
    }

    final nonAligningChildrenWidth =
        nonAligningSizes.map((size) => size.width).maxOrNull ?? 0.0;
    final aligningChildrenWidth = colWidths.sum;
    width = math.max(nonAligningChildrenWidth, aligningChildrenWidth);

    // Second pass, re-layout each RenderLine using column width constraint
    var index = 0;
    var vPos = 0.0;
    if (!dry) {
      hlinePos.add(vPos);
    }
    index++;
    child = firstChild;
    final baselines = <double>[];
    while (child != null && index <= rowCount) {
      final childParentData = child.parentData as EqnArrayParentData;
      var hPos = 0.0;
      final childSize = sizeMap[child] ?? Size.zero;
      if (child is RenderLine && child.alignColWidth != null) {
        child.alignColWidth = colWidths;
        // Hack: We use a different constraint to trigger another layout or
        // else it would be bypassed
        child.layout(BoxConstraints(maxWidth: aligningChildrenWidth),
            parentUsesSize: true);
        hPos = (width - aligningChildrenWidth) / 2 +
            colWidths[0] -
            child.alignColWidth![0];
      } else {
        hPos = (width - childSize.width) / 2;
      }
      final layoutHeight = dry ? 0 : child.layoutHeight;
      final layoutDepth = dry ? childSize.height : child.layoutDepth;

      vPos += math.max(layoutHeight, 0.7 * arrayskip);
      baselines.add(vPos);
      if (!dry) {
        childParentData.offset = Offset(
          hPos,
          vPos - child.layoutHeight,
        );
      }
      vPos += math.max(layoutDepth, 0.3 * arrayskip) +
          jotSize +
          rowSpacings[index - 1];
      if (!dry) {
        hlinePos.add(vPos);
      }
      vPos += hlines[index] != MatrixSeparatorStyle.none ? ruleThickness : 0.0;
      index++;

      child = childParentData.nextSibling;
    }

    if (!dry) {
      this.width = width;
    }

    // The tags: one right-aligned column after the rows (KaTeX puts them
    // at the right edge), each on its row's baseline.
    final tags = <RenderBox, Size>{};
    var tagWidth = 0.0;
    for (var i = 0; child != null && i < baselines.length; i++) {
      final tagSize = child.getLayoutSize(infiniteConstraint, dry: dry);
      tags[child] = tagSize;
      tagWidth = math.max(tagWidth, tagSize.width);
      child = (child.parentData! as EqnArrayParentData).nextSibling;
    }
    if (tagWidth == 0) return Size(width, vPos);
    if (!dry) {
      var i = 0;
      for (final MapEntry(key: tag, value: tagSize) in tags.entries) {
        final tagBaseline =
            tag.getDistanceToBaseline(TextBaseline.alphabetic) ?? 0.0;
        (tag.parentData! as EqnArrayParentData).offset = Offset(
          width + tagGap + tagWidth - tagSize.width,
          baselines[i++] - tagBaseline,
        );
      }
    }
    return Size(width + tagGap + tagWidth, vPos);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    for (var i = 0; i < hlines.length; i++) {
      if (hlines[i] != MatrixSeparatorStyle.none) {
        context.canvas.drawLine(
          Offset(0, hlinePos[i] + ruleThickness / 2),
          Offset(width, hlinePos[i] + ruleThickness / 2),
          Paint()..strokeWidth = ruleThickness,
        );
      }
      // TODO dashed line
    }
  }
}
