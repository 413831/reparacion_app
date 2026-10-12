import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// [JobSummaryCard] demonstrates the modular typography scale of Plus Jakarta Sans
/// optimized for users aged 30 to 50 in work/outdoor environments:
/// - Trade Title: [TextTheme.titleLarge] (20sp, SemiBold 600)
/// - Status Badge: [TextTheme.labelMedium] (13sp, Medium 500)
/// - Schedule Date & Physical Address: [TextTheme.bodyLarge] (16sp, Regular 400 / Medium 500)
/// - Secondary details & budget: [TextTheme.bodyMedium] (14sp, Regular 400)
/// - CTA Action Button: [TextTheme.labelLarge] (16sp, SemiBold 600)
class JobSummaryCard extends StatelessWidget {
  final String tradeTitle;
  final String status; // 'agendado', 'pendiente_de_aceptacion', 'finalizado', 'cancelado'
  final String scheduledDateText;
  final String addressText;
  final String? budgetEstimateText;
  final String actionButtonText;
  final VoidCallback onActionPressed;
  final VoidCallback? onCardTap;

  const JobSummaryCard({
    super.key,
    required this.tradeTitle,
    required this.status,
    required this.scheduledDateText,
    required this.addressText,
    this.budgetEstimateText,
    required this.actionButtonText,
    required this.onActionPressed,
    this.onCardTap,
  });

  String _formatStatusLabel(String rawStatus) {
    switch (rawStatus) {
      case 'agendado':
        return 'Agendado';
      case 'pendiente_de_aceptacion':
        return 'Pendiente';
      case 'finalizado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return rawStatus;
    }
  }

  Color _getStatusColor(String rawStatus) {
    switch (rawStatus) {
      case 'agendado':
        return AppColors.info;
      case 'finalizado':
        return AppColors.success;
      case 'cancelado':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Trade Title (titleLarge) + Status Badge (labelMedium)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      tradeTitle,
                      // Escala: titleLarge (20sp, SemiBold 600, height 1.3)
                      style: textTheme.titleLarge?.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatStatusLabel(status),
                          // Escala: labelMedium (13sp, Medium 500, height 1.3)
                          style: textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Date Info (bodyLarge: 16sp, height 1.45)
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scheduledDateText,
                      // Escala: bodyLarge (16sp, Regular 400 / Medium 500)
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Physical Address (bodyLarge: 16sp, height 1.45)
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 19,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      addressText,
                      // Escala: bodyLarge (16sp, Regular 400)
                      style: textTheme.bodyLarge?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (budgetEstimateText != null) ...[
                const SizedBox(height: 10),
                // Budget / Scope Metadata (bodyMedium: 14sp, height 1.4)
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        budgetEstimateText!,
                        // Escala: bodyMedium (14sp, Regular 400)
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const Divider(height: 28),

              // CTA Action Button (labelLarge: 16sp, SemiBold 600, height 1.2)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onActionPressed,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    actionButtonText,
                    // Escala: labelLarge (16sp, SemiBold 600)
                    style: textTheme.labelLarge?.copyWith(
                      color: isDark ? AppColors.buttonTextDark : AppColors.buttonTextLight,
                      fontWeight: isDark ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
