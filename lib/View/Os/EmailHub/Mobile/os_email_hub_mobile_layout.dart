import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// On native apps, keep WebView out of the scrollable form; open it in a dialog only.
/// (Avoids platform-channel errors when the hub route builds and on wide phones/tablets.)
bool osEmailHubCollapsePreview(BuildContext context) {
  return !kIsWeb;
}