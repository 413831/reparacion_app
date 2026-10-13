import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';

/// ForcedUpdateScreen blocks user interaction when the running app
/// build is below the minimum operational requirement set by the backend.
///
/// Wraps in PopScope(canPop: false) to prevent Android back gestures
/// and iOS edge swipes from bypassing store review requirements.
class ForcedUpdateScreen extends StatelessWidget {
  final String storeUrl;
  final String message;
  final int minBuild;
  final int currentBuild;

  const ForcedUpdateScreen({
    super.key,
    required this.storeUrl,
    required this.message,
    this.minBuild = 2,
    this.currentBuild = 1,
  });

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.tryParse(storeUrl);
    if (uri != null) {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor abrí Google Play Store o Apple App Store para actualizar.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // Strict block: User cannot navigate back
      child: Scaffold(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // Warning / Shield Icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 48,
                    color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                  ),
                ),
                const SizedBox(height: 28),

                // Compliance Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security_update_warning_rounded, size: 16, color: AppColors.danger),
                      SizedBox(width: 6),
                      Text(
                        'Actualización Requerida',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Main Heading
                Text(
                  'Nueva Versión de Reparatutti',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Explanatory Copy
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 28),

                // Version comparison pill
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Tu Versión', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            'Build $currentBuild',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 28, color: Colors.grey.withValues(alpha: 0.3)),
                      Column(
                        children: [
                          const Text('Mínima Requerida', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            'Build $minBuild',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Store Redirect CTA
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _openStore(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                      foregroundColor: AppColors.pureBlack,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text(
                      'Actualizar en la Tienda',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'El uso de versiones anteriores está deshabilitado por seguridad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
