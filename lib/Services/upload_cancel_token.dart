/// Thrown when an in-flight upload is cancelled by the user.
class UploadCancelledException implements Exception {
  const UploadCancelledException();

  @override
  String toString() => 'UploadCancelledException';
}

/// Cooperative cancellation token for R2 uploads.
class UploadCancelToken {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  set onCancel(void Function()? callback) => _onCancel = callback;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
  }

  void throwIfCancelled() {
    if (_cancelled) throw const UploadCancelledException();
  }
}
