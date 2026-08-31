// The real, web-only implementation — selected by page_title.dart's
// conditional export. Only ever compiled when building for web, so a
// dart:html import here is safe even though it doesn't exist for native
// targets.
import 'dart:html' as html;

void setPageTitle(String title) {
  html.document.title = title;
}
