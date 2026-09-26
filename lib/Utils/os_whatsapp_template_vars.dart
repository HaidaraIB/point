import 'package:point/Models/Os/OsWhatsappLogModel.dart';

/// Where a `{{token}}` appears in a Meta template.
enum OsWhatsappPlaceholderComponent {
  header,
  body,
  buttonUrl,
}

class OsWhatsappTemplatePlaceholder {
  const OsWhatsappTemplatePlaceholder({
    required this.component,
    required this.token,
    required this.contextSnippet,
    this.buttonIndex = 0,
  });

  final OsWhatsappPlaceholderComponent component;
  /// Token inside braces without `{{` `}}`, e.g. `customer_name` or `1`.
  final String token;
  final String contextSnippet;
  final int buttonIndex;

  bool get isNamed => !RegExp(r'^\d+$').hasMatch(token);
}

final RegExp _whatsappPlaceholderToken =
    RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}');

/// Ordered placeholders as they appear in header, body, then URL buttons.
List<OsWhatsappTemplatePlaceholder> osWhatsappExtractPlaceholders(
  OsWhatsappTemplateModel template,
) {
  final out = <OsWhatsappTemplatePlaceholder>[];
  var buttonIdx = 0;

  for (final raw in template.components) {
    final map = _componentMap(raw);
    if (map == null) continue;
    final type = (map['type'] as String?)?.toUpperCase() ?? '';

    if (type == 'HEADER') {
      final format = (map['format'] as String?)?.toUpperCase() ?? 'TEXT';
      if (format == 'TEXT') {
        final text = map['text'] as String? ?? '';
        _appendFromText(out, text, OsWhatsappPlaceholderComponent.header);
      }
    } else if (type == 'BODY') {
      final text = map['text'] as String? ?? '';
      _appendFromText(out, text, OsWhatsappPlaceholderComponent.body);
    } else if (type == 'BUTTONS') {
      final buttons = map['buttons'];
      if (buttons is! List) continue;
      for (final btn in buttons) {
        final btnMap = _componentMap(btn);
        if (btnMap == null) continue;
        final btnType = (btnMap['type'] as String?)?.toUpperCase() ?? '';
        if (btnType == 'URL') {
          final url = btnMap['url'] as String? ?? '';
          for (final m in _whatsappPlaceholderToken.allMatches(url)) {
            final token = m.group(1) ?? '';
            if (token.isEmpty) continue;
            out.add(
              OsWhatsappTemplatePlaceholder(
                component: OsWhatsappPlaceholderComponent.buttonUrl,
                token: token,
                contextSnippet: _snippetAround(url, m.start),
                buttonIndex: buttonIdx,
              ),
            );
          }
        }
        buttonIdx++;
      }
    }
  }
  return out;
}

void _appendFromText(
  List<OsWhatsappTemplatePlaceholder> out,
  String text,
  OsWhatsappPlaceholderComponent component,
) {
  for (final m in _whatsappPlaceholderToken.allMatches(text)) {
    final token = m.group(1) ?? '';
    if (token.isEmpty) continue;
    out.add(
      OsWhatsappTemplatePlaceholder(
        component: component,
        token: token,
        contextSnippet: _snippetAround(text, m.start),
      ),
    );
  }
}

String _snippetAround(String text, int index) {
  final start = index > 40 ? index - 40 : 0;
  final end = (index + 40).clamp(0, text.length);
  return text.substring(start, end).replaceAll('\n', ' ').trim();
}

Map<String, dynamic>? _componentMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

/// Approved Meta URL per button index (only `URL` buttons).
Map<int, String> osWhatsappUrlButtonTemplateUrls(
  OsWhatsappTemplateModel template,
) {
  final out = <int, String>{};
  var buttonIdx = 0;
  for (final raw in template.components) {
    final map = _componentMap(raw);
    if (map == null) continue;
    final type = (map['type'] as String?)?.toUpperCase() ?? '';
    if (type != 'BUTTONS') continue;
    final buttons = map['buttons'];
    if (buttons is! List) continue;
    for (final btn in buttons) {
      final btnMap = _componentMap(btn);
      if (btnMap == null) {
        buttonIdx++;
        continue;
      }
      final btnType = (btnMap['type'] as String?)?.toUpperCase() ?? '';
      if (btnType == 'URL') {
        final url = (btnMap['url'] as String?)?.trim() ?? '';
        if (url.isNotEmpty) out[buttonIdx] = url;
      }
      buttonIdx++;
    }
  }
  return out;
}

/// Meta URL buttons must pass only the dynamic suffix, not the full pay URL.
String osWhatsappUrlButtonParameterValue({
  required String templateButtonUrl,
  required String token,
  required String resolvedValue,
}) {
  final value = resolvedValue.trim();
  if (value.isEmpty) return value;

  final placeholder = '{{$token}}';
  final phIdx = templateButtonUrl.indexOf(placeholder);
  if (phIdx < 0) return value;

  final prefix = templateButtonUrl.substring(0, phIdx);
  final suffix = templateButtonUrl.substring(phIdx + placeholder.length);

  if (!value.contains('://') && !value.toLowerCase().contains('pay.html')) {
    return value;
  }

  if (prefix.isNotEmpty && value.startsWith(prefix)) {
    var rest = value.substring(prefix.length);
    if (suffix.isNotEmpty && rest.endsWith(suffix)) {
      rest = rest.substring(0, rest.length - suffix.length);
    }
    if (rest.isNotEmpty) return rest;
  }

  try {
    final uri = Uri.parse(value);
    final t = uri.queryParameters['t']?.trim();
    if (t != null && t.isNotEmpty) return t;
  } catch (_) {}

  return value;
}

/// Invoice templates with a fixed `pay.html` button cannot vary per invoice.
bool osWhatsappHasStaticPayHtmlButton(OsWhatsappTemplateModel template) {
  for (final url in osWhatsappUrlButtonTemplateUrls(template).values) {
    if (!url.toLowerCase().contains('pay.html')) continue;
    if (!_whatsappPlaceholderToken.hasMatch(url)) return true;
  }
  return false;
}

/// Graph API template parameter (numbered or named).
class OsWhatsappGraphTextParameter {
  const OsWhatsappGraphTextParameter({
    required this.text,
    this.token,
  });

  final String text;
  final String? token;

  bool get isNamed =>
      token != null && token!.isNotEmpty && !RegExp(r'^\d+$').hasMatch(token!);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': 'text',
      'text': text,
    };
    if (token != null && token!.isNotEmpty) {
      map['token'] = token;
    }
    if (isNamed) {
      map['parameter_name'] = token;
    }
    return map;
  }
}

/// Substitute placeholder values into template body text for preview.
String osWhatsappSubstitutePlaceholders(
  String text,
  Map<String, String> valuesByToken,
) {
  var out = text;
  for (final e in valuesByToken.entries) {
    out = out.replaceAll('{{${e.key}}}', e.value);
    if (RegExp(r'^\d+$').hasMatch(e.key)) {
      out = out.replaceAll('{{${e.key}}}', e.value);
    }
  }
  return out;
}

/// Build ordered parameter lists for header, body, and URL buttons.
class OsWhatsappBuiltTemplateParameters {
  const OsWhatsappBuiltTemplateParameters({
    this.header = const [],
    this.body = const [],
    this.buttonUrlByIndex = const {},
  });

  final List<OsWhatsappGraphTextParameter> header;
  final List<OsWhatsappGraphTextParameter> body;
  final Map<int, List<OsWhatsappGraphTextParameter>> buttonUrlByIndex;
}

OsWhatsappBuiltTemplateParameters osWhatsappBuildGraphParameters(
  OsWhatsappTemplateModel template,
  Map<String, String> valuesByToken,
) {
  final placeholders = osWhatsappExtractPlaceholders(template);
  final buttonUrls = osWhatsappUrlButtonTemplateUrls(template);
  final header = <OsWhatsappGraphTextParameter>[];
  final body = <OsWhatsappGraphTextParameter>[];
  final buttonUrlByIndex = <int, List<OsWhatsappGraphTextParameter>>{};

  for (final p in placeholders) {
    var text = valuesByToken[p.token] ?? '';
    switch (p.component) {
      case OsWhatsappPlaceholderComponent.header:
        header.add(OsWhatsappGraphTextParameter(text: text, token: p.token));
        break;
      case OsWhatsappPlaceholderComponent.body:
        body.add(OsWhatsappGraphTextParameter(text: text, token: p.token));
        break;
      case OsWhatsappPlaceholderComponent.buttonUrl:
        final templateUrl = buttonUrls[p.buttonIndex];
        if (templateUrl != null) {
          text = osWhatsappUrlButtonParameterValue(
            templateButtonUrl: templateUrl,
            token: p.token,
            resolvedValue: text,
          );
        }
        buttonUrlByIndex
            .putIfAbsent(p.buttonIndex, () => [])
            .add(OsWhatsappGraphTextParameter(text: text, token: p.token));
        break;
    }
  }

  return OsWhatsappBuiltTemplateParameters(
    header: header,
    body: body,
    buttonUrlByIndex: buttonUrlByIndex,
  );
}
