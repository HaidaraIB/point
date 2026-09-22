import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/Services/os_voucher_balance.dart';

void main() {
  group('osVoucherBalanceEffect', () {
    test('receipt is positive', () {
      expect(
        osVoucherBalanceEffect(
          type: OsVoucherType.receipt,
          amount: 100,
        ),
        100,
      );
    });

    test('payment is negative', () {
      expect(
        osVoucherBalanceEffect(
          type: OsVoucherType.payment,
          amount: 50,
        ),
        -50,
      );
    });
  });

  group('computeOsAccountNetDeltas', () {
    test('same account amount change', () {
      final nets = computeOsAccountNetDeltas(
        removeLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'a1',
            type: OsVoucherType.receipt,
            amount: 100,
          ),
        ],
        applyLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'a1',
            type: OsVoucherType.receipt,
            amount: 150,
          ),
        ],
      );
      expect(nets, {'a1': 50});
    });

    test('same account type flip', () {
      final nets = computeOsAccountNetDeltas(
        removeLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'a1',
            type: OsVoucherType.receipt,
            amount: 100,
          ),
        ],
        applyLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'a1',
            type: OsVoucherType.payment,
            amount: 100,
          ),
        ],
      );
      expect(nets, {'a1': -200});
    });

    test('account move reverses old and applies new', () {
      final nets = computeOsAccountNetDeltas(
        removeLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'a1',
            type: OsVoucherType.payment,
            amount: 200,
          ),
        ],
        applyLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'a2',
            type: OsVoucherType.payment,
            amount: 200,
          ),
        ],
      );
      expect(nets, {'a1': 200, 'a2': -200});
    });

    test('transfer pair nets source and dest once', () {
      final nets = computeOsAccountNetDeltas(
        removeLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'src',
            type: OsVoucherType.payment,
            amount: 1000,
          ),
          OsVoucherBalanceLeg(
            accountId: 'dst',
            type: OsVoucherType.receipt,
            amount: 1000,
          ),
        ],
        applyLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'src',
            type: OsVoucherType.payment,
            amount: 500,
          ),
          OsVoucherBalanceLeg(
            accountId: 'dst',
            type: OsVoucherType.receipt,
            amount: 500,
          ),
        ],
      );
      expect(nets, {'src': 500, 'dst': -500});
    });

    test('no-op when cash fields unchanged', () {
      final nets = computeOsAccountNetDeltas(
        removeLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'a1',
            type: OsVoucherType.receipt,
            amount: 100,
          ),
        ],
        applyLegs: const [
          OsVoucherBalanceLeg(
            accountId: 'a1',
            type: OsVoucherType.receipt,
            amount: 100,
          ),
        ],
      );
      expect(nets, isEmpty);
    });
  });

  group('findOsInsufficientBalanceAccount', () {
    test('rejects when net would go negative', () {
      final blocked = findOsInsufficientBalanceAccount(
        balancesByAccountId: {'cash': 50},
        netDeltasByAccountId: {'cash': -100},
      );
      expect(blocked, 'cash');
    });

    test('allows no-op when account already overdrawn', () {
      final blocked = findOsInsufficientBalanceAccount(
        balancesByAccountId: {'cash': -10},
        netDeltasByAccountId: {},
      );
      expect(blocked, isNull);
    });

    test('allows when net is zero on overdrawn account', () {
      final blocked = findOsInsufficientBalanceAccount(
        balancesByAccountId: {'cash': -10},
        netDeltasByAccountId: {'cash': 0},
      );
      expect(blocked, isNull);
    });
  });
}
