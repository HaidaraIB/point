/// CRM pipeline stages and lead sources (point_os parity).
class OsCrmStage {
  OsCrmStage._();

  static const newLead = 'NEW_LEAD';
  static const contacted = 'CONTACTED';
  static const quotationSent = 'QUOTATION_SENT';
  static const negotiation = 'NEGOTIATION';
  static const won = 'WON';
  static const inProgress = 'IN_PROGRESS';
  static const lost = 'LOST';

  static const ordered = [
    newLead,
    contacted,
    quotationSent,
    negotiation,
    won,
    inProgress,
    lost,
  ];

  static String effective(String? raw) {
    if (raw != null && ordered.contains(raw)) return raw;
    return newLead;
  }
}

class OsLeadSource {
  OsLeadSource._();

  static const whatsapp = 'WHATSAPP';
  static const instagram = 'INSTAGRAM';
  static const referral = 'REFERRAL';
  static const website = 'WEBSITE';
  static const ads = 'ADS';

  static const all = [whatsapp, instagram, referral, website, ads];
}
