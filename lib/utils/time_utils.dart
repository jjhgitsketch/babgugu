DateTime parseSupabaseServerTime(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return DateTime.now();
  final normalized = _normalizeDateTimeText(text);
  final hasTimeZone = _hasTimeZone(normalized);
  final parsed = DateTime.parse(hasTimeZone ? normalized : '${normalized}Z');
  return parsed.toLocal();
}

DateTime parseSupabaseLocalTime(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return DateTime.now();
  final normalized = _normalizeDateTimeText(text);
  final parsed = DateTime.parse(normalized);
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

String _normalizeDateTimeText(String text) {
  return text.contains('T') ? text : text.replaceFirst(' ', 'T');
}

bool _hasTimeZone(String text) {
  return text.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
}
