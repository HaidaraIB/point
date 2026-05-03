/// Single-file upload limit for [HomeController.uploadFiles] and Supabase Storage.
///
/// Ensure the Supabase Storage bucket **global file size limit** (Dashboard →
/// Storage → bucket → configuration) is at least this value, or uploads will
/// fail at the server.
const int kMaxUploadMegabytes = 150;
const int kMaxUploadBytes = kMaxUploadMegabytes * 1024 * 1024;
