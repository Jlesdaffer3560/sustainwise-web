// Sets the browser tab's title — every SustainWise tab otherwise shows the
// same static "SustainWise" from index.html regardless of which page is
// open, which is disorienting with more than one tab open (a normal
// website updates its tab title per page; a single-page Flutter app
// doesn't, unless it does this explicitly). A no-op on native, via the
// conditional export below — dart:html doesn't exist there.
export 'page_title_stub.dart' if (dart.library.html) 'page_title_web.dart';
