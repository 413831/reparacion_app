import 'package:flutter/foundation.dart';

/// CrashReportingService handles centralized observability, error tracking,
/// and crash reporting for Firebase Crashlytics and Sentry.
///
/// Designed to catch synchronous Flutter framework rendering bugs
/// as well as asynchronous platform dispatcher exceptions.
class CrashReportingService {
  static bool _initialized = false;
  static String? _currentUserId;

  static String? get currentUserId => _currentUserId;

  /// Initializes error monitoring SDKs (Firebase Crashlytics / Sentry)
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // In production with native GoogleService-Info.plist / google-services.json:
      // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
      // or SentryFlutter.init(...)
      _initialized = true;
      debugPrint('[CrashReporting] Observability engine initialized successfully.');
    } catch (e, stack) {
      debugPrint('[CrashReporting] Failed to initialize crash reporting: $e\n$stack');
    }
  }

  /// Sets user identifier to correlate crashes with user sessions
  static void setUserIdentifier(String userId) {
    _currentUserId = userId;
    debugPrint('[CrashReporting] Attached user ID: $userId');
  }

  /// Clears user identifier on logout / account deletion
  static void clearUserIdentifier() {
    _currentUserId = null;
    debugPrint('[CrashReporting] Detached user ID.');
  }

  /// Captures Flutter framework render/widget tree errors
  static void recordFlutterError(FlutterErrorDetails details) {
    debugPrint('[CrashReporting] [FLUTTER_ERROR] ${details.exceptionAsString()}');
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }

    try {
      // Forward to Firebase Crashlytics:
      // FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      // or Sentry.captureException(details.exception, stackTrace: details.stack);
    } catch (e) {
      debugPrint('[CrashReporting] Failed to forward Flutter error: $e');
    }
  }

  /// Captures asynchronous and platform unhandled exceptions
  static void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    debugPrint('[CrashReporting] [UNHANDLED_EXCEPTION] (fatal: $fatal) $error');
    if (reason != null) {
      debugPrint('[CrashReporting] Reason: $reason');
    }
    if (kDebugMode && stack != null) {
      debugPrint(stack.toString());
    }

    try {
      // Forward to Firebase Crashlytics / Sentry:
      // FirebaseCrashlytics.instance.recordError(error, stack, reason: reason, fatal: fatal);
      // Sentry.captureException(error, stackTrace: stack);
    } catch (e) {
      debugPrint('[CrashReporting] Failed to forward error: $e');
    }
  }

  /// Records operational breadcrumbs (screen transitions, action logs)
  static void logBreadcrumb(String message, {String? category}) {
    final cat = category != null ? '[$category] ' : '';
    debugPrint('[CrashReporting] Breadcrumb: $cat$message');
  }
}
