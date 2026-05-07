/// Naming for final-deliverable uploads: human-readable download names tied to the task title.

/// Sanitizes [title] for use as a file name segment (no path separators / illegal chars).
String sanitizeTaskTitleForFileBase(String title) {
  const maxLen = 120;
  var s = title.trim();
  if (s.isEmpty) return 'deliverable';
  s = s.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return 'deliverable';
  if (s.length > maxLen) {
    s = s.substring(0, maxLen).trim();
  }
  return s.isEmpty ? 'deliverable' : s;
}

/// Original file extension including the leading dot, or empty if none.
String extensionWithDotFromOriginal(String originalName) {
  final n = originalName.trim();
  final dot = n.lastIndexOf('.');
  if (dot <= 0 || dot >= n.length - 1) return '';
  return n.substring(dot);
}

/// First attachment: `[title][ext]`. Next: `[title] 1[ext]`, `[title] 2[ext]`, …
///
/// [slotIndex] is zero-based among final deliverable URLs **before** this file is added
/// (i.e. current list length when starting the upload for this file).
String finalDeliverableDownloadDisplayName({
  required String taskTitle,
  required int slotIndex,
  required String originalFileName,
}) {
  final base = sanitizeTaskTitleForFileBase(taskTitle);
  var ext = extensionWithDotFromOriginal(originalFileName);
  if (ext.isEmpty) {
    ext = '.bin';
  }
  if (slotIndex <= 0) {
    return '$base$ext';
  }
  return '$base $slotIndex$ext';
}

/// **Legacy — Supabase Storage only.** Supabase public URLs accept a `download`
/// query param for the saved file name. R2 uploads use `Content-Disposition` set
/// at upload time by the presign worker instead.
String appendSupabaseStorageDownloadQuery(String publicUrl, String downloadFileName) {
  final trimmed = downloadFileName.trim();
  if (trimmed.isEmpty) return publicUrl;
  final u = Uri.tryParse(publicUrl);
  if (u == null) return publicUrl;
  final qp = Map<String, String>.from(u.queryParameters);
  qp['download'] = trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed;
  return u.replace(queryParameters: qp).toString();
}
