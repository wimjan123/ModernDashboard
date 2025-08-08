import '../exceptions/initialization_exception.dart';

enum InitializationPhase {
  networkCheck,
  configValidation,
  firebaseInit,
  authentication,
  repositoryInit,
  success,
  error,
  retrying,
}

class InitializationStatus {
  final InitializationPhase phase;
  final int currentAttempt;
  final int maxAttempts;
  final String message;
  final double? progress;
  final Duration? nextRetryIn;
  final bool isRetrying;
  final InitializationException? error;

  const InitializationStatus({
    required this.phase,
    this.currentAttempt = 1,
    this.maxAttempts = 3,
    required this.message,
    this.progress,
    this.nextRetryIn,
    this.isRetrying = false,
    this.error,
  });

  bool get isInProgress =>
      phase != InitializationPhase.success && phase != InitializationPhase.error;

  bool get isComplete =>
      phase == InitializationPhase.success || phase == InitializationPhase.error;

  String get displayMessage {
    if (isRetrying && nextRetryIn != null) {
      final seconds = nextRetryIn!.inSeconds;
      return '$message (retrying in ${seconds}s)';
    }
    if (currentAttempt > 1 && isInProgress) {
      return '$message (attempt $currentAttempt of $maxAttempts)';
    }
    return message;
  }

  InitializationStatus copyWith({
    InitializationPhase? phase,
    int? currentAttempt,
    int? maxAttempts,
    String? message,
    double? progress,
    Duration? nextRetryIn,
    bool? isRetrying,
    InitializationException? error,
  }) {
    return InitializationStatus(
      phase: phase ?? this.phase,
      currentAttempt: currentAttempt ?? this.currentAttempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      nextRetryIn: nextRetryIn ?? this.nextRetryIn,
      isRetrying: isRetrying ?? this.isRetrying,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'InitializationStatus('
        'phase: $phase, '
        'attempt: $currentAttempt/$maxAttempts, '
        'message: $message, '
        'progress: $progress, '
        'isRetrying: $isRetrying'
        ')';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InitializationStatus &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          currentAttempt == other.currentAttempt &&
          maxAttempts == other.maxAttempts &&
          message == other.message &&
          progress == other.progress &&
          nextRetryIn == other.nextRetryIn &&
          isRetrying == other.isRetrying &&
          error == other.error;

  @override
  int get hashCode =>
      phase.hashCode ^
      currentAttempt.hashCode ^
      maxAttempts.hashCode ^
      message.hashCode ^
      progress.hashCode ^
      nextRetryIn.hashCode ^
      isRetrying.hashCode ^
      error.hashCode;
}