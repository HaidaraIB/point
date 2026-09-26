import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppTranslations.dart';
import 'package:point/Models/Os/OsLineItem.dart';
import 'package:point/Services/email/email_html_builders.dart';
import 'package:point/Services/email/email_html_shell.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.addTranslations(AppTranslations().keys);
    Get.updateLocale(const Locale('ar'));
  });

  tearDown(Get.reset);

  test('escapeHtml escapes unsafe characters', () {
    expect(
      EmailHtmlShell.escape('<script>"&\'</script>'),
      '&lt;script&gt;&quot;&amp;&#39;&lt;/script&gt;',
    );
  });

  test('detectLocale identifies Arabic text', () {
    expect(EmailHtmlShell.detectLocale('مرحباً'), 'ar');
    expect(EmailHtmlShell.detectLocale('Hello world'), 'en');
  });

  test('invoice builder renders RTL table and payment CTA', () {
    final html = EmailHtmlBuilders.invoice(
      locale: 'ar',
      subtitle: 'فاتورة',
      heading: 'فاتورة INV-001',
      greeting: 'مرحباً العميل،',
      intro: 'نرفق الفاتورة.',
      reference: 'INV-001',
      totalLabel: 'المبلغ المستحق',
      totalAmount: '650,000 د.ع',
      dueDateLabel: 'تاريخ الاستحقاق',
      dueDate: '2026-09-30',
      items: const [
        OsLineItem(
          id: '1',
          description: 'تصميم',
          quantity: 2,
          unitPrice: 100000,
          total: 200000,
        ),
      ],
      colItem: 'البند',
      colQty: 'الكمية',
      colTotal: 'الإجمالي',
      customNote: 'ملاحظة مخصصة',
      paymentLink: 'https://pay.example.com/inv-001',
      payCtaLabel: 'ادفع الآن',
      signature: 'مع التحية',
    );

    expect(html, contains('dir="rtl"'));
    expect(html, contains('lang="ar"'));
    expect(html, contains('تصميم'));
    expect(html, contains('ملاحظة مخصصة'));
    expect(html, contains('https://pay.example.com/inv-001'));
    expect(html, contains('ادفع الآن'));
    expect(html, contains('align="center"'));
    expect(html, contains('background-color:${EmailBrand.primaryDark}'));
    expect(html, contains('مع التحية'));
    expect(html, isNot(contains('بيانات التحويل')));
    expect(html, isNot(contains('<script>')));
  });

  test('payslip builder renders earnings and net pay band', () {
    final html = EmailHtmlBuilders.payslip(
      locale: 'ar',
      subtitle: 'قسيمة راتب',
      heading: 'قسيمة سبتمبر 2026',
      greeting: 'مرحباً تيست،',
      period: 'سبتمبر 2026',
      employeeName: 'تيست موظف',
      positionLabel: 'المسمى',
      position: 'مصمم',
      emailLabel: 'البريد',
      email: 'test@example.com',
      earningsTitle: 'الاستحقاقات',
      deductionsTitle: 'الخصومات',
      basicLabel: 'الراتب الأساسي',
      basicAmount: '500,000 د.ع',
      allowancesLabel: 'البدلات',
      allowancesAmount: '150,000 د.ع',
      deductionsLabel: 'الخصومات',
      deductionsAmount: '0 د.ع',
      netPayLabel: 'صافي الراتب',
      netPayAmount: '650,000 د.ع',
      paymentMethodLabel: 'طريقة الدفع',
      paymentMethod: 'حساب بنكي',
    );

    expect(html, contains('تيست موظف'));
    expect(html, contains('500,000 د.ع'));
    expect(html, contains('650,000 د.ع'));
    expect(html, contains('حساب بنكي'));
  });

  test('notification builder renders details table', () {
    final html = EmailHtmlBuilders.notification(
      locale: 'en',
      subtitle: 'App notification',
      title: 'Payslip ready',
      greeting: 'Hello Employee,',
      summary: 'Your payslip is ready.',
      notificationTimeLabel: 'Notification time',
      notificationTime: '2026-09-19 10:00',
      actionLabel: 'Action',
      actionText: 'Open the app',
      autoFooter: 'Sent automatically.',
      quickDetailsTitle: 'Quick details',
      details: const {
        'Net pay': '650,000 IQD',
        'Period': 'September 2026',
      },
    );

    expect(html, contains('dir="ltr"'));
    expect(html, contains('Payslip ready'));
    expect(html, contains('Net pay'));
    expect(html, contains('650,000 IQD'));
  });
}
