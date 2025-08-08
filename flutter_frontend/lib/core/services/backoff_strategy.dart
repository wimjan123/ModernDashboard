import 'dart:math';

class BackoffStrategy {
  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;
  final double jitterFactor;
  final int maxAttempts;

  BackoffStrategy({
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.jitterFactor = 0.1,
    this.maxAttempts = 3,
  }) {
    if (initialDelay.inMilliseconds <= 0) {
      throw ArgumentError('initialDelay must be positive');
    }
    if (maxDelay.inMilliseconds <= 0) {
      throw ArgumentError('maxDelay must be positive');
    }
    if (initialDelay > maxDelay) {
      throw ArgumentError('initialDelay must be <= maxDelay');
    }
    if (multiplier <= 0) {
      throw ArgumentError('multiplier must be positive');
    }
    if (jitterFactor < 0 || jitterFactor > 1) {
      throw ArgumentError('jitterFactor must be between 0 and 1');
    }
    if (maxAttempts <= 0) {
      throw ArgumentError('maxAttempts must be positive');
    }
  }

  factory BackoffStrategy.conservative() {
    return BackoffStrategy(
      initialDelay: const Duration(seconds: 5),
      maxDelay: const Duration(minutes: 2),
      multiplier: 2.5,
      jitterFactor: 0.2,
      maxAttempts: 5,
    );
  }

  factory BackoffStrategy.aggressive() {
    return BackoffStrategy(
      initialDelay: const Duration(milliseconds: 500),
      maxDelay: const Duration(seconds: 10),
      multiplier: 1.5,
      jitterFactor: 0.05,
      maxAttempts: 10,
    );
  }

  factory BackoffStrategy.testing() {
    return BackoffStrategy(
      initialDelay: const Duration(milliseconds: 100),
      maxDelay: const Duration(milliseconds: 500),
      multiplier: 1.2,
      jitterFactor: 0.1,
      maxAttempts: 3,
    );
  }

  Duration calculateDelay(int attempt) {
    if (attempt <= 1) {
      return Duration.zero;
    }

    final attemptIndex = attempt - 2;
    final baseDelay = initialDelay.inMilliseconds * pow(multiplier, attemptIndex);
    final cappedDelay = min(baseDelay, maxDelay.inMilliseconds.toDouble());

    final random = Random();
    final jitter = 1.0 + (random.nextDouble() * 2 - 1) * jitterFactor;
    final finalDelay = (cappedDelay * jitter).round();

    return Duration(milliseconds: finalDelay);
  }

  bool shouldRetry(int attempt) {
    return attempt <= maxAttempts;
  }

  Duration getRemainingDelay(int attempt, DateTime startTime) {
    final totalDelay = calculateDelay(attempt);
    final elapsed = DateTime.now().difference(startTime);
    final remaining = totalDelay - elapsed;
    
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  String toString() {
    return 'BackoffStrategy('
        'initialDelay: $initialDelay, '
        'maxDelay: $maxDelay, '
        'multiplier: $multiplier, '
        'jitterFactor: $jitterFactor, '
        'maxAttempts: $maxAttempts'
        ')';
  }
}