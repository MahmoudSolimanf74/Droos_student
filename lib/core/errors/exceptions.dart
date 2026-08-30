class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'حدث خطأ في الاتصال بالخادم']);
  @override
  String toString() => message;
}

class AppAuthException implements Exception {
  final String message;
  const AppAuthException([this.message = 'فشل تسجيل الدخول']);
  @override
  String toString() => message;
}
