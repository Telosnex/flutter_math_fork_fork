import 'dart:async';

import 'golden_tolerance/golden_tolerance_stub.dart'
    if (dart.library.io) 'golden_tolerance/golden_tolerance_io.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  installGoldenTolerance();
  await testMain();
}
