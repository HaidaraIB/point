class OsPayslipBatchResult {
  const OsPayslipBatchResult({
    this.sent = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  final int sent;
  final int skipped;
  final int failed;

  bool get hasAnySent => sent > 0;
}
