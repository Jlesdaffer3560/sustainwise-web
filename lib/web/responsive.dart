import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Below this width, a visitor is treated as being on a phone-ish browser
/// and gets the same single-column layout (and bottom tab bar) as the
/// native app — the sidebar shell only makes sense once there's actually
/// room for it. Raised from an original 760 after external review pointed
/// out the sidebar plus Home's own further 2-column split left very little
/// room for the right-hand column just above this width.
const double kDesktopBreakpoint = 900;

/// Below this width, a desktop-shell (sidebar) view still gets a single
/// content column — [kDesktopBreakpoint] is only enough room for the
/// sidebar itself, not also for Home's second column of status cards
/// alongside a comfortably wide module list.
const double kWideDesktopBreakpoint = 1150;

bool isDesktopWeb(BuildContext context) =>
    kIsWeb && MediaQuery.of(context).size.width >= kDesktopBreakpoint;

bool isWideDesktopWeb(BuildContext context) =>
    kIsWeb && MediaQuery.of(context).size.width >= kWideDesktopBreakpoint;
