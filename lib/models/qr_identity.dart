class QrIdentity {
  const QrIdentity({required this.token});

  static const schemePrefix = 'haychat://contact/v1/';

  final String token;

  String get payload => '$schemePrefix$token';

  static String? tokenFromPayload(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith(schemePrefix)) return null;
    final token = trimmed.substring(schemePrefix.length);
    return RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(token) ? token : null;
  }
}

class QrProfile {
  const QrProfile({
    required this.token,
    required this.ownerId,
    required this.displayName,
    required this.photoUrl,
    required this.status,
  });

  final String token;
  final String ownerId;
  final String displayName;
  final String photoUrl;
  final String status;
}
