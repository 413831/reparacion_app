import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/services/version_check_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/navigation/presentation/forced_update_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Observability & Crash Reporting (Crashlytics / Sentry)
  await CrashReportingService.initialize();

  // 2. Global Exception Handling: Flutter Framework widget tree errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashReportingService.recordFlutterError(details);
  };

  // 3. Global Exception Handling: Asynchronous & PlatformDispatcher errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    CrashReportingService.recordError(error, stack, fatal: true);
    return true; // Mark as handled to avoid hard OS crashes
  };

  runApp(
    const ProviderScope(
      child: ReparatuttiApp(),
    ),
  );
}

class ReparatuttiApp extends ConsumerWidget {
  const ReparatuttiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Startup Service: Check Remote Config for minimum required build before routing
    final updateState = ref.watch(appUpdateStateProvider);

    return updateState.when(
      data: (result) {
        if (result.needsForceUpdate) {
          // Blocking: Display ForcedUpdateScreen preventing user bypass
          return MaterialApp(
            title: 'Reparatutti',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            home: ForcedUpdateScreen(
              storeUrl: result.storeUrl,
              message: result.message,
              minBuild: result.minRequiredBuild,
              currentBuild: result.currentBuild,
            ),
          );
        }

        // App is up to date: Proceed to main router
        return MaterialApp.router(
          title: 'Reparatutti',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          routerConfig: AppRouter.router,
        );
      },
      loading: () => MaterialApp.router(
        title: 'Reparatutti',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
      ),
      error: (err, stack) {
        CrashReportingService.recordError(err, stack, reason: 'Startup version check error');
        return MaterialApp.router(
          title: 'Reparatutti',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
