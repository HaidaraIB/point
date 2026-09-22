import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';

/// Contact fields collected on invoice and quotation forms.
const kOsFinanceDocumentContactFields = <OsClientContactField>[
  OsClientContactField.phone,
  OsClientContactField.email,
  OsClientContactField.address,
];

/// Contact fields collected on legal contract client party forms.
const kOsLegalContractClientContactFields = <OsClientContactField>[
  OsClientContactField.name,
  OsClientContactField.company,
  OsClientContactField.phone,
  OsClientContactField.email,
  OsClientContactField.address,
];

/// Contact fields on [ClientModel] that OS document forms may collect.
enum OsClientContactField {
  name,
  phone,
  email,
  address,
  company,
}

bool osClientContactValuePresent(String? value) =>
    value != null && value.trim().isNotEmpty;

String? osClientContactFieldValue(
  ClientModel client,
  OsClientContactField field,
) {
  switch (field) {
    case OsClientContactField.name:
      return client.name;
    case OsClientContactField.phone:
      return client.phone;
    case OsClientContactField.email:
      return client.email;
    case OsClientContactField.address:
      return client.address;
    case OsClientContactField.company:
      return client.company;
  }
}

/// Returns fields that are empty on [client] among [fields].
Set<OsClientContactField> osClientMissingContactFields(
  ClientModel client, {
  required Iterable<OsClientContactField> fields,
}) {
  return {
    for (final field in fields)
      if (!osClientContactValuePresent(
        osClientContactFieldValue(client, field),
      ))
        field,
  };
}

/// Values typed in a form for contact fields.
class OsClientContactDraft {
  const OsClientContactDraft({
    this.name,
    this.phone,
    this.email,
    this.address,
    this.company,
  });

  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final String? company;

  String? valueFor(OsClientContactField field) {
    switch (field) {
      case OsClientContactField.name:
        return name;
      case OsClientContactField.phone:
        return phone;
      case OsClientContactField.email:
        return email;
      case OsClientContactField.address:
        return address;
      case OsClientContactField.company:
        return company;
    }
  }
}

/// Merges [draft] into [client] only for keys that are currently empty.
ClientModel osClientMergeEmptyContactFields(
  ClientModel client,
  OsClientContactDraft draft, {
  required Iterable<OsClientContactField> fields,
}) {
  var merged = client;
  for (final field in fields) {
    if (osClientContactValuePresent(osClientContactFieldValue(merged, field))) {
      continue;
    }
    final typed = draft.valueFor(field)?.trim() ?? '';
    if (typed.isEmpty) continue;
    switch (field) {
      case OsClientContactField.name:
        merged = merged.copyWith(name: typed);
      case OsClientContactField.phone:
        merged = merged.copyWith(phone: typed);
      case OsClientContactField.email:
        merged = merged.copyWith(email: typed);
      case OsClientContactField.address:
        merged = merged.copyWith(address: typed);
      case OsClientContactField.company:
        merged = merged.copyWith(company: typed);
    }
  }
  return merged;
}

/// Resolves document contact values from client record + typed draft.
/// [client] wins for fields it already has; [draft] fills the rest.
OsClientContactDraft osResolveDocumentContact({
  required ClientModel client,
  required OsClientContactDraft draft,
  required Iterable<OsClientContactField> fields,
}) {
  String? pick(OsClientContactField field) {
    final fromClient = osClientContactFieldValue(client, field)?.trim();
    if (osClientContactValuePresent(fromClient)) return fromClient;
    final fromDraft = draft.valueFor(field)?.trim();
    return fromDraft != null && fromDraft.isNotEmpty ? fromDraft : null;
  }

  return OsClientContactDraft(
    name: fields.contains(OsClientContactField.name)
        ? pick(OsClientContactField.name)
        : draft.name,
    phone: fields.contains(OsClientContactField.phone)
        ? pick(OsClientContactField.phone)
        : draft.phone,
    email: fields.contains(OsClientContactField.email)
        ? pick(OsClientContactField.email)
        : draft.email,
    address: fields.contains(OsClientContactField.address)
        ? pick(OsClientContactField.address)
        : draft.address,
    company: fields.contains(OsClientContactField.company)
        ? pick(OsClientContactField.company)
        : draft.company,
  );
}

/// When editing an existing document, keep stored document values for fields
/// the client already had at save time; use [resolved] for missing client fields.
OsClientContactDraft osPreserveExistingDocumentContact({
  required OsClientContactDraft? existingDocument,
  required OsClientContactDraft resolved,
  required Set<OsClientContactField> clientHadAtEdit,
}) {
  if (existingDocument == null) return resolved;

  String? pick(OsClientContactField field) {
    if (clientHadAtEdit.contains(field)) {
      final existing = existingDocument.valueFor(field)?.trim();
      if (osClientContactValuePresent(existing)) return existing;
    }
    return resolved.valueFor(field);
  }

  return OsClientContactDraft(
    name: pick(OsClientContactField.name),
    phone: pick(OsClientContactField.phone),
    email: pick(OsClientContactField.email),
    address: pick(OsClientContactField.address),
    company: pick(OsClientContactField.company),
  );
}

/// Whether [field] should appear in the form for [client].
/// When [client] is null (custom / not linked), all fields are shown.
bool osShowClientContactField({
  required ClientModel? client,
  required OsClientContactField field,
  required Iterable<OsClientContactField> fields,
}) {
  if (client == null) return true;
  return osClientMissingContactFields(client, fields: fields).contains(field);
}

/// Snapshot of contact fields present on [client] when editing a document.
Set<OsClientContactField> osClientContactFieldsPresent(
  ClientModel client, {
  required Iterable<OsClientContactField> fields,
}) {
  return {
    for (final field in fields)
      if (osClientContactValuePresent(
        osClientContactFieldValue(client, field),
      ))
        field,
  };
}

InputDecoration osClientContactFieldDecoration(
  InputDecoration base, {
  required bool savesToClient,
}) {
  if (!savesToClient) return base;
  return base.copyWith(
    helperText: AppLocaleKeys.osClientContactSaveToClientHint.tr,
    helperMaxLines: 2,
  );
}
