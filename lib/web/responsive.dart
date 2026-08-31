import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Below this width, a visitor is treated as being on a phone-ish browser
/// and gets the same single-column layout (and bottom tab bar) as the
/// native app — the sidebar shell only makes sense once there's actually
/// room for it.
const double kDesktopBreakpoint = 760;

bool isDesktopWeb(BuildContext context) =>
    kIsWeb && MediaQuery.of(context).size.width >= kDesktopBreakpoint;
