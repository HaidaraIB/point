/// Single-file upload limit for [HomeController.uploadFiles] (Cloudflare R2).
///
/// R2 allows large objects; this cap keeps memory usage predictable (files are
/// read fully into RAM with `FilePicker(withData: true)` before upload).
/// Adjust if you change the picker / streaming strategy.
const int kMaxUploadMegabytes = 200;
const int kMaxUploadBytes = kMaxUploadMegabytes * 1024 * 1024;
