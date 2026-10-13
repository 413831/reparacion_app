import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/terms_and_conditions_screen.dart';
import '../../features/kyc/presentation/kyc_verification_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/home/presentation/home_dashboard_screen.dart';
import '../../features/navigation/presentation/forced_update_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeDashboardScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/force-update',
        builder: (context, state) {
          final storeUrl = state.uri.queryParameters['storeUrl'] ?? 'https://apps.apple.com';
          final message = state.uri.queryParameters['message'] ??
              'Una actualización crítica es requerida para continuar utilizando Reparatutti.';
          final minBuild = int.tryParse(state.uri.queryParameters['minBuild'] ?? '2') ?? 2;
          final currentBuild = int.tryParse(state.uri.queryParameters['currentBuild'] ?? '1') ?? 1;

          return ForcedUpdateScreen(
            storeUrl: storeUrl,
            message: message,
            minBuild: minBuild,
            currentBuild: currentBuild,
          );
        },
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => TermsAndConditionsScreen(
          onAccepted: () => context.go('/'),
        ),
      ),
      GoRoute(
        path: '/kyc',
        builder: (context, state) {
          final isTech = state.uri.queryParameters['role'] != 'client';
          return KYCVerificationScreen(isTechnician: isTech);
        },
      ),
      GoRoute(
        path: '/chat/:jobId',
        builder: (context, state) {
          final jobId = state.pathParameters['jobId'] ?? '44444444-4444-4444-4444-444444444444';
          return ChatScreen(jobId: jobId);
        },
      ),
    ],
  );
}
