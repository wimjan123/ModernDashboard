class InitializationException implements Exception {
  final String code;
  final String message;
  final String? details;

  const InitializationException(
    this.code,
    this.message, [
    this.details,
  ]);

  @override
  String toString() {
    if (details != null) {
      return 'InitializationException($code): $message\nDetails: $details';
    }
    return 'InitializationException($code): $message';
  }
}