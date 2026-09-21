/// WhatsApp dispatch categories (aligned with log `type` field).
class OsWhatsappCategory {
  OsWhatsappCategory._();

  static const invoice = 'INVOICE';
  static const custom = 'CUSTOM';
  static const crm = 'CRM';
}

/// Delivery status on [OsWhatsappLogModel].
class OsWhatsappLogStatus {
  OsWhatsappLogStatus._();

  static const sent = 'SENT';
  static const failed = 'FAILED';
}

/// Hub send mode (Meta template vs customer-service session message).
class OsWhatsappHubSendMode {
  OsWhatsappHubSendMode._();

  static const template = 'TEMPLATE';
  static const session = 'SESSION';
}

/// [OsWhatsappLogModel.templateName] when the send was a session message.
class OsWhatsappLogTemplateName {
  OsWhatsappLogTemplateName._();

  static const session = 'SESSION';
}
