class JoinCodeHelper {
  JoinCodeHelper._();

  /// Extracts the group join code or token from raw input, deep links, or QR URLs.
  /// Handles formats like:
  /// - `classpilot://join?token=XYZ&code=ABC123`
  /// - `https://.../join?code=ABC123`
  /// - `code=ABC123`
  /// - `ABC123`
  static String extractCode(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '';

    if (clean.contains('code=') || clean.contains('token=')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        if (uri.queryParameters.containsKey('code')) {
          final code = uri.queryParameters['code']?.trim();
          if (code != null && code.isNotEmpty) return code;
        }
        if (uri.queryParameters.containsKey('token')) {
          final token = uri.queryParameters['token']?.trim();
          if (token != null && token.isNotEmpty) return token;
        }
      }
      final matchCode = RegExp(r'code=([a-zA-Z0-9_\u0600-\u06FF-]+)').firstMatch(clean);
      if (matchCode != null) return matchCode.group(1)!;

      final matchToken = RegExp(r'token=([a-zA-Z0-9_\u0600-\u06FF-]+)').firstMatch(clean);
      if (matchToken != null) return matchToken.group(1)!;
    }

    return clean;
  }
}
