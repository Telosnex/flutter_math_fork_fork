part of '../functions.dart';

EncodeResult _smashEncoder(GreenNode node) {
  final smash = node as SmashNode;
  if (!smash.smashHeight && !smash.smashDepth) {
    return encodeTex(smash.body);
  }
  return TexCommandEncodeResult(
    command: '\\smash',
    args: <dynamic>[
      smash.smashHeight && smash.smashDepth
          ? null
          : (smash.smashHeight ? 't' : 'b'),
      smash.body,
    ],
  );
}

EncodeResult _lapEncoder(GreenNode node) {
  final lap = node as LapNode;
  return TexCommandEncodeResult(
    command: switch (lap.alignment) {
      LapAlignment.left => '\\mathllap',
      LapAlignment.right => '\\mathrlap',
      LapAlignment.center => '\\mathclap',
    },
    args: lap.children,
  );
}
