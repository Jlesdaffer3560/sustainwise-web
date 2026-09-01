import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Wraps [child] in a Flutter-native saturation reduction on web — a
/// deliberate replacement for an earlier global `filter: saturate(80%)`
/// CSS rule on the whole canvas, per external review feedback that a
/// blanket CSS filter is "technically not ideal" (it dulls every icon and
/// badge along with the colors actually being complained about). This
/// targets exactly the learning-path section instead, where the
/// full-saturation unit accents (red/pink/lime/violet) live — nothing
/// else on the page is touched, and native never calls this at all.
///
/// The matrix is the standard luminance-preserving saturation formula
/// (Rec. 601 weights 0.213/0.715/0.072). Originally 80% (matching the CSS
/// rule it replaced); dropped to 45% after a second external review still
/// called the eight-unit rainbow "too busy" even at 80% — units stay
/// distinguishable by hue, just calmer. Native colors are untouched either
/// way, since this only ever runs on web.
Widget desaturatedOnWeb(Widget child) {
  if (!kIsWeb) return child;
  return ColorFiltered(colorFilter: const ColorFilter.matrix(_kSatMatrix), child: child);
}

const double _lumR = 0.213;
const double _lumG = 0.715;
const double _lumB = 0.072;
const double _s = 0.45;

const List<double> _kSatMatrix = [
  _lumR + _s * (1 - _lumR), _lumG * (1 - _s), _lumB * (1 - _s), 0, 0,
  _lumR * (1 - _s), _lumG + _s * (1 - _lumG), _lumB * (1 - _s), 0, 0,
  _lumR * (1 - _s), _lumG * (1 - _s), _lumB + _s * (1 - _lumB), 0, 0,
  0, 0, 0, 1, 0,
];
