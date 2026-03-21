import 'package:web/web.dart';

/// Web: `document.hidden` is true when the tab is in the background.
bool get isBrowserTabHidden => document.hidden;
