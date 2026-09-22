import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';

/// One voucher leg's effect on a single bank account.
class OsVoucherBalanceLeg {
  const OsVoucherBalanceLeg({
    required this.accountId,
    required this.type,
    required this.amount,
  });

  final String accountId;
  final String type;
  final double amount;

  factory OsVoucherBalanceLeg.fromVoucher(OsVoucherModel voucher) {
    return OsVoucherBalanceLeg(
      accountId: voucher.bankAccountId,
      type: voucher.type,
      amount: voucher.amount,
    );
  }
}

/// Signed balance effect: receipt +amount, payment −amount.
double osVoucherBalanceEffect({required String type, required double amount}) {
  return type == OsVoucherType.payment ? -amount : amount;
}

/// Net delta per account when replacing [removeLegs] with [applyLegs].
Map<String, double> computeOsAccountNetDeltas({
  required List<OsVoucherBalanceLeg> removeLegs,
  required List<OsVoucherBalanceLeg> applyLegs,
}) {
  final nets = <String, double>{};

  void add(String accountId, double delta) {
    final id = accountId.trim();
    if (id.isEmpty || delta.abs() < 0.0001) return;
    nets[id] = (nets[id] ?? 0) + delta;
  }

  for (final leg in removeLegs) {
    add(
      leg.accountId,
      -osVoucherBalanceEffect(type: leg.type, amount: leg.amount),
    );
  }
  for (final leg in applyLegs) {
    add(
      leg.accountId,
      osVoucherBalanceEffect(type: leg.type, amount: leg.amount),
    );
  }

  nets.removeWhere((_, v) => v.abs() < 0.0001);
  return nets;
}

/// Returns the first account id whose balance would go negative, or null if ok.
String? findOsInsufficientBalanceAccount({
  required Map<String, double> balancesByAccountId,
  required Map<String, double> netDeltasByAccountId,
}) {
  for (final entry in netDeltasByAccountId.entries) {
    if (entry.value.abs() < 0.0001) continue;
    final current = balancesByAccountId[entry.key] ?? 0;
    if (current + entry.value < -0.0001) {
      return entry.key;
    }
  }
  return null;
}

/// Whether voucher type may change during edit (manual / legacy only).
bool osVoucherTypeChangeAllowed(OsVoucherModel voucher) {
  if (voucher.invoiceId != null && voucher.invoiceId!.trim().isNotEmpty) {
    return false;
  }
  final source = voucher.source?.trim() ?? '';
  if (source.isEmpty) return true;
  return source == OsVoucherSource.manual;
}
