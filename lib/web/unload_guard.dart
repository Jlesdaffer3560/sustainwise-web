// Warns before closing/refreshing the tab while mid-lesson, mid-quiz, or
// mid-review — a native app has no equivalent "close the tab" action to
// lose progress to, but a website visitor might reflexively hit refresh.
// Nothing here persists that progress; it only stops it from being lost
// *by surprise*. A no-op on native, via the conditional export below.
//
// pushUnloadGuard() in initState(), popUnloadGuard() in dispose(), for
// every screen that represents an in-progress, not-yet-scored attempt
// (LessonScreen, QuizScreen, PairsScreen, ReviewScreen,
// ExpertChallengeScreen).
export 'unload_guard_stub.dart' if (dart.library.html) 'unload_guard_web.dart';
