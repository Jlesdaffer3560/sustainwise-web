// The real, web-only implementation — selected by unload_guard.dart's
// conditional export. A reference count, not a plain bool: Lesson → Quiz →
// Pairs replace each other via pushReplacement with an animated
// transition, so the outgoing screen's dispose() and the incoming
// screen's initState() can briefly overlap in either order. Only clearing
// the browser's own beforeunload handler once the count reaches zero
// means the warning stays active for the whole in-progress flow
// regardless of that overlap, instead of flickering off mid-transition.
import 'dart:async';
import 'dart:html' as html;

int _count = 0;
StreamSubscription<html.Event>? _sub;

void pushUnloadGuard() {
  _count++;
  _sub ??= html.window.onBeforeUnload.listen((event) {
    // Chrome and most browsers show their own generic "leave site?"
    // wording regardless of this string; setting it is still required by
    // the beforeunload spec to trigger that native prompt at all.
    (event as html.BeforeUnloadEvent).returnValue =
        'Your progress in this lesson will be lost.';
  });
}

void popUnloadGuard() {
  _count = _count > 0 ? _count - 1 : 0;
  if (_count == 0) {
    _sub?.cancel();
    _sub = null;
  }
}
