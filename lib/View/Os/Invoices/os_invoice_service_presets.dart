/// Default agency service packages matching point_os AppContext seed data.
/// Used for invoice line quick-add until a full Services hub exists.
class OsInvoiceServicePreset {
  const OsInvoiceServicePreset({
    required this.id,
    required this.name,
    required this.basePrice,
  });

  final String id;
  final String name;
  final double basePrice;
}

const osInvoiceServicePresets = <OsInvoiceServicePreset>[
  OsInvoiceServicePreset(
    id: 'SRV-01',
    name: 'تصوير فوتوغرافي احترافي',
    basePrice: 1500000,
  ),
  OsInvoiceServicePreset(
    id: 'SRV-02',
    name: 'إنتاج فيديوهات تسويقية',
    basePrice: 5000000,
  ),
  OsInvoiceServicePreset(
    id: 'SRV-03',
    name: 'مونتاج وتحرير فيديو سينمائي',
    basePrice: 75000,
  ),
  OsInvoiceServicePreset(
    id: 'SRV-04',
    name: 'إدارة وحملات السوشيال ميديا',
    basePrice: 2000000,
  ),
  OsInvoiceServicePreset(
    id: 'SRV-05',
    name: 'الهوية البصرية المتكاملة',
    basePrice: 3500000,
  ),
];
