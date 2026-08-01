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

