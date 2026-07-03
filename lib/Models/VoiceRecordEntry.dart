class VoiceRecordEntry {
  final String url;
  final int durationSec;

  const VoiceRecordEntry({
    required this.url,
    this.durationSec = 0,
  });

  factory VoiceRecordEntry.fromJson(dynamic json) {
    if (json is! Map) {
      return const VoiceRecordEntry(url: '');
    }
    return VoiceRecordEntry(
      url: json['url']?.toString() ?? json['voiceRecordUrl']?.toString() ?? '',
      durationSec: (json['durationSec'] as num?)?.toInt() ??
          (json['voiceRecordDurationSec'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (durationSec > 0) 'durationSec': durationSec,
      };

  static List<VoiceRecordEntry> listFromJson(Map<String, dynamic> json) {
    final raw = json['voiceRecords'];
    if (raw is List) {
      return raw
          .map(VoiceRecordEntry.fromJson)
          .where((e) => e.url.trim().isNotEmpty)
          .toList();
    }
    final legacyUrl = json['voiceRecordUrl']?.toString().trim() ?? '';
    if (legacyUrl.isEmpty) return const [];
    return [
      VoiceRecordEntry(
        url: legacyUrl,
        durationSec: (json['voiceRecordDurationSec'] as num?)?.toInt() ?? 0,
      ),
    ];
  }

  static List<Map<String, dynamic>> listToJson(List<VoiceRecordEntry> records) {
    return records
        .where((e) => e.url.trim().isNotEmpty)
        .map((e) => e.toJson())
        .toList();
  }

  static String primaryUrl(List<VoiceRecordEntry> records) =>
      records.isNotEmpty ? records.first.url : '';

  static int primaryDurationSec(List<VoiceRecordEntry> records) =>
      records.isNotEmpty ? records.first.durationSec : 0;
}
