List<String> normalizeMetaPlatformsForFirestore(List<dynamic> selectedKeys) {
  final out = <String>{};
  for (final s in selectedKeys) {
    final t = s.toString().toLowerCase();
    if (t.contains('facebook')) out.add('facebook');
    if (t.contains('instagram')) out.add('instagram');
  }
  return out.toList();
}

String publishPathLower(String url) {
  try {
    return Uri.parse(url).path.toLowerCase();
  } catch (_) {
    return url.split('?').first.toLowerCase();
  }
}

String publishFileKindFromUrl(String url) {
  final p = publishPathLower(url);
  if (p.endsWith('.jpg') ||
      p.endsWith('.jpeg') ||
      p.endsWith('.png') ||
      p.endsWith('.webp') ||
      p.endsWith('.gif')) {
    return 'image';
  }
  if (p.endsWith('.mp4') ||
      p.endsWith('.mov') ||
      p.endsWith('.webm') ||
      p.endsWith('.m4v') ||
      p.endsWith('.avi') ||
      p.endsWith('.mkv')) {
    return 'video';
  }
  return 'unknown';
}

String? publishMediaTypeFromUrl(String url) {
  switch (publishFileKindFromUrl(url)) {
    case 'image':
      return 'photo';
    case 'video':
      return 'video';
    default:
      return null;
  }
}

/// Media type for a stored URL, never null when a URL exists.
/// Signed / extensionless storage URLs are unrecognizable by extension, so fall
/// back to the type implied by the post type instead of leaving it empty (the
/// bot rejects a media-less Instagram feed / story / reel row).
String publishMediaTypeFromUrlOrPostType(String url, String postType) {
  final detected = publishMediaTypeFromUrl(url);
  if (detected != null) return detected;
  return postType.trim().toLowerCase() == 'reel' ? 'video' : 'photo';
}

/// Mirrors `_validate_publish_payload_rules` in the upload-to-meta bot so the
/// app never queues a row the worker will reject with a `meta_err_*` code.
/// Returns the translation key of the first broken rule, or null when valid.
String? metaPublishBlockingErrorKey({
  required List<String> platforms,
  required String postType,
  String? mediaType,
  String? caption,
  String? instagramUserId,
}) {
  final fs = normalizeMetaPlatformsForFirestore(platforms);
  final type = postType.trim().toLowerCase();
  final media = (mediaType ?? '').trim().toLowerCase();
  final text = (caption ?? '').trim();
  final igUserId = (instagramUserId ?? '').trim();

  if (fs.isEmpty) return 'meta_err_no_platforms';
  if (type == 'reel' && media != 'video') return 'meta_err_reel_requires_video';
  if (type == 'story' && media.isEmpty) return 'meta_err_story_requires_media';
  if (type == 'feed' && media.isEmpty && fs.contains('instagram')) {
    return 'meta_err_instagram_no_text_only';
  }
  if (fs.contains('instagram') && igUserId.isEmpty) {
    return 'meta_err_missing_ig_user_id';
  }
  if (fs.contains('facebook') &&
      type == 'feed' &&
      media.isEmpty &&
      text.isEmpty) {
    return 'meta_err_fb_text_requires_caption';
  }
  return null;
}

