import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/View/Os/os_client_contact_fields.dart';

ClientModel _client({
  String? name,
  String? phone,
  String? email,
  String? address,
  String? company,
}) {
  return ClientModel(
    id: 'c1',
    name: name,
    phone: phone,
    email: email,
    address: address,
    company: company,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  group('osClientMissingContactFields', () {
    test('returns only empty fields among requested keys', () {
      final client = _client(name: 'Acme', phone: '9647', email: ' ');
      final missing = osClientMissingContactFields(
        client,
        fields: kOsFinanceDocumentContactFields,
      );
      expect(missing, {
        OsClientContactField.email,
        OsClientContactField.address,
      });
    });
  });

  group('osClientMergeEmptyContactFields', () {
    test('fills only empty client fields from draft', () {
      final client = _client(name: 'Acme', phone: '9647');
      final merged = osClientMergeEmptyContactFields(
        client,
        const OsClientContactDraft(
          name: 'Override',
          phone: '999',
          email: 'new@example.com',
          address: 'Baghdad',
        ),
        fields: kOsFinanceDocumentContactFields,
      );
      expect(merged.name, 'Acme');
      expect(merged.phone, '9647');
      expect(merged.email, 'new@example.com');
      expect(merged.address, 'Baghdad');
    });
  });

  group('osResolveDocumentContact', () {
    test('prefers client values over draft when client has them', () {
      final client = _client(phone: '9647000', email: 'client@example.com');
      final resolved = osResolveDocumentContact(
        client: client,
        draft: const OsClientContactDraft(
          phone: '111',
          email: 'typed@example.com',
          address: 'Draft address',
        ),
        fields: kOsFinanceDocumentContactFields,
      );
      expect(resolved.phone, '9647000');
      expect(resolved.email, 'client@example.com');
      expect(resolved.address, 'Draft address');
    });
  });

  group('osPreserveExistingDocumentContact', () {
    test('keeps document values for fields client already had when editing', () {
      final preserved = osPreserveExistingDocumentContact(
        existingDocument: const OsClientContactDraft(
          phone: '9647111',
          email: 'old-invoice@example.com',
        ),
        resolved: const OsClientContactDraft(
          phone: '9647999',
          email: 'new@example.com',
        ),
        clientHadAtEdit: {OsClientContactField.phone, OsClientContactField.email},
      );
      expect(preserved.phone, '9647111');
      expect(preserved.email, 'old-invoice@example.com');
    });
  });

  group('osShowClientContactField', () {
    test('shows all fields for custom client', () {
      expect(
        osShowClientContactField(
          client: null,
          field: OsClientContactField.phone,
          fields: kOsFinanceDocumentContactFields,
        ),
        isTrue,
      );
    });

    test('hides phone when client already has it', () {
      final client = _client(phone: '9647');
      expect(
        osShowClientContactField(
          client: client,
          field: OsClientContactField.phone,
          fields: kOsFinanceDocumentContactFields,
        ),
        isFalse,
      );
    });
  });
}
