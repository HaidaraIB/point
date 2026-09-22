import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppTranslations.dart';
import 'package:point/Models/Os/OsPayslipModel.dart';
import 'package:point/Models/Os/OsVoucherModel.dart';
import 'package:point/Models/Os/os_finance_enums.dart';
import 'package:point/View/Os/Finance/os_voucher_print_text.dart';
import 'package:point/View/Os/Payroll/os_payslip_print_text.dart';
import 'package:point/View/Os/os_print_a4.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.addTranslations(AppTranslations().keys);
    Get.updateLocale(const Locale('ar'));
  });

  tearDown(Get.reset);

  group('osPrintSingleSheet / osPrintTwoCopies', () {
    test('single sheet has one page and no copy watermark', () {
      final html = osPrintSingleSheet(innerHtml: '<p>x</p>');
      expect(RegExp(r'<div class="a4">').allMatches(html).length, 1);
      expect(html, isNot(contains('copy-watermark')));
    });

    test('two copies has two pages with agency and client labels', () {
      final html = osPrintTwoCopies(innerHtml: '<p>x</p>');
      expect(RegExp(r'<div class="a4">').allMatches(html).length, 2);
      expect(html, contains('copy-watermark'));
      expect(html, contains('نسخة الوكالة'));
      expect(html, contains('نسخة العميل'));
    });
  });

  group('buildOsVoucherPrintHtml forPdf', () {
    final voucher = OsVoucherModel(
      displayNumber: 'V-105',
      type: OsVoucherType.payment,
      amount: 550,
      date: '2026-09-19',
      payeeOrPayer: 'تصميم',
      description: 'fsdafas',
      bankAccountId: 'acc1',
      createdAt: DateTime(2026, 9, 19),
    );

    test('forPdf produces one clean page', () {
      final html = buildOsVoucherPrintHtml(
        voucher: voucher,
        accountName: 'test',
        forPdf: true,
      );
      expect(RegExp(r'<div class="a4">').allMatches(html).length, 1);
      expect(html, isNot(contains('<div class="copy-watermark"')));
      expect(html, isNot(contains('class="watermark-logo"')));
      expect(html, contains('V-105'));
    });

    test('print produces two copy pages with watermarks', () {
      final html = buildOsVoucherPrintHtml(
        voucher: voucher,
        accountName: 'test',
      );
      expect(RegExp(r'<div class="a4">').allMatches(html).length, 2);
      expect(html, contains('<div class="copy-watermark"'));
      expect(html, contains('نسخة الوكالة'));
      expect(html, contains('نسخة العميل'));
    });
  });

  group('buildOsPayslipPrintHtml forPdf', () {
    final slip = OsPayslipModel(
      period: '2026-09',
      employeeId: 'emp-design',
      employeeName: 'تصميم',
      basicSalary: 0,
      netPay: 0,
      displayNumber: 'SLIP-2026-09-D8754558',
      createdAt: DateTime(2026, 9, 22),
    );

    test('forPdf produces one clean page', () {
      final html = buildOsPayslipPrintHtml(slip, forPdf: true);
      expect(RegExp(r'<div class="a4">').allMatches(html).length, 1);
      expect(html, isNot(contains('<div class="copy-watermark"')));
      expect(html, isNot(contains('class="watermark-logo"')));
      expect(html, contains('SLIP-2026-09-D8754558'));
      expect(html, contains('brand-header'));
    });

    test('print produces two copy pages with watermarks', () {
      final html = buildOsPayslipPrintHtml(slip);
      expect(RegExp(r'<div class="a4">').allMatches(html).length, 2);
      expect(html, contains('<div class="copy-watermark"'));
      expect(html, contains('نسخة الوكالة'));
      expect(html, contains('نسخة العميل'));
      expect(html, contains('brand-header'));
    });
  });
}
