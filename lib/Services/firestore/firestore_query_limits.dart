/// Firestore query caps to stay within Spark plan quotas.
class FirestoreQueryLimits {
  FirestoreQueryLimits._();

  static const int chatMessagesPage = 50;
  /// Max pinned rows fetched per open chat (typically 1–5; cheap vs full history).
  static const int pinnedMessages = 20;
  static const int employees = 200;
  static const int clients = 500;
  static const int contents = 500;
  static const int metaPosts = 500;
  static const int tasks = 500;
  static const int libraryFiles = 2000;
  static const int notifications = 50;
  static const int osInvoices = 500;
  static const int osQuotations = 500;
  static const int osBankAccounts = 200;
  static const int osVouchers = 500;
  static const int osExpenses = 500;
  static const int osPayrollRuns = 200;
  static const int osPayslips = 500;
  static const int osContracts = 500;
  static const int osLegalContracts = 500;
  static const int osLegalContractTemplates = 100;
  static const int osAdvances = 500;
  static const int osBranches = 50;
  static const int osServices = 100;
  static const int osEmailLogs = 200;
}
