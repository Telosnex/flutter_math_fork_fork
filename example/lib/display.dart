import 'package:flutter_math_fork_fork/flutter_math.dart';
import 'package:material_ui/material_ui.dart';

class DisplayMath extends StatelessWidget {
  final String expression;

  const DisplayMath({
    Key? key,
    required this.expression,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(expression, softWrap: true),
            ),
            Divider(
              thickness: 1.0,
              height: 1.0,
            ),
            Expanded(
              child: Center(child: Math.tex(expression)),
            )
          ],
        ),
      );
}
