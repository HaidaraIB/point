import 'dart:convert';

/// Production Qi Card host; used when the live base URL is left empty.
/// Mirrors `QICARD_LIVE_DEFAULT_HOST` in `supabase/functions/_shared/qicard.ts`.
const String kQicardLiveDefaultHost = 'https://3ds-api.qi.iq';

/// Trims, strips a trailing `/`, then a trailing `/api/v1` (same rules as the
/// Edge Function, so the preview in settings matches what is called).
String normalizeQicardBaseUrl(String raw) => raw
    .trim()
    .replaceFirst(RegExp(r'/+$'), '')
    .replaceFirst(RegExp(r'/api/v1$', caseSensitive: false), '')
    .replaceFirst(RegExp(r'/+$'), '');

/// API root that live requests will use, e.g. `https://3ds-api.qi.iq/api/v1`.
String qicardEffectiveLiveApiRoot(String raw) {
  final host = normalizeQicardBaseUrl(raw);
  return '${host.isEmpty ? kQicardLiveDefaultHost : host}/api/v1';
}

/// Empty is valid (falls back to the default host).
bool isValidQicardBaseUrl(String raw) {
  final normalized = normalizeQicardBaseUrl(raw);
  if (normalized.isEmpty) return true;
  final uri = Uri.tryParse(normalized);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.contains('.') &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

enum QicardPemCheck { empty, valid, privateKey, invalid }

/// Strips a BOM and normalizes line endings (files saved on Windows).
String cleanQicardPem(String raw) =>
    raw.replaceAll('﻿', '').replaceAll('\r\n', '\n').trim();

const _pemBegin = '-----BEGIN PUBLIC KEY-----';
const _pemEnd = '-----END PUBLIC KEY-----';

/// Checks for an SPKI public key PEM (what Qi provides as `rsapubkey.pem`).
QicardPemCheck checkQicardPublicKeyPem(String raw) {
  final text = cleanQicardPem(raw);
  if (text.isEmpty) return QicardPemCheck.empty;
  if (text.contains('PRIVATE KEY')) return QicardPemCheck.privateKey;
  final begin = text.indexOf(_pemBegin);
  final end = text.indexOf(_pemEnd);
  if (begin < 0 || end <= begin) return QicardPemCheck.invalid;
  final body = text
      .substring(begin + _pemBegin.length, end)
      .replaceAll(RegExp(r'\s'), '');
  try {
    // A 1024-bit RSA SPKI is ~160 bytes; anything tiny is a truncated paste.
    return base64.decode(body).length >= 64
        ? QicardPemCheck.valid
        : QicardPemCheck.invalid;
  } on FormatException {
    return QicardPemCheck.invalid;
  }
}
