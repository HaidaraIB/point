/// Sentinel value for "custom client" in OS finance document forms.
const kOsCustomClientId = '__os_custom_client__';

bool osIsCustomClientId(String? clientId) => clientId == kOsCustomClientId;

bool osDocumentHasCustomClient({required String clientId}) {
  final id = clientId.trim();
  return id.isEmpty || osIsCustomClientId(id);
}
