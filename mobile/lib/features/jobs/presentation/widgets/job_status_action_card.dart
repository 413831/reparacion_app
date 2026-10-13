import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class JobStatusActionCard extends StatelessWidget {
  final String currentStatus; // 'pendiente_de_aceptacion', 'agendado', 'finalizado', 'cancelado'
  final bool isClient;
  final bool clientConfirmed;
  final bool techConfirmed;
  final VoidCallback onConfirmAgendado;
  final VoidCallback onConfirmFinalizado;
  final VoidCallback onConfirmCancelado;

  const JobStatusActionCard({
    super.key,
    required this.currentStatus,
    required this.isClient,
    required this.clientConfirmed,
    required this.techConfirmed,
    required this.onConfirmAgendado,
    required this.onConfirmFinalizado,
    required this.onConfirmCancelado,
  });

  String _formatStatusName(String status) {
    switch (status) {
      case 'pendiente_de_aceptacion':
        return 'Pendiente de Aceptación';
      case 'agendado':
        return 'Agendado Oficialmente';
      case 'finalizado':
        return 'Servicio Finalizado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(currentStatus);
    final userHasConfirmed = isClient ? clientConfirmed : techConfirmed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Global State
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync_alt_rounded, size: 20, color: AppColors.mustardLight),
                  SizedBox(width: 8),
                  Text(
                    'Regla de Doble Confirmación',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatStatusName(currentStatus),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Double Confirmation Trackers (Client vs Tech)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161616) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPartyStatus(
                    role: 'Cliente',
                    confirmed: clientConfirmed,
                    isCurrentUser: isClient,
                    isDark: isDark,
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                Expanded(
                  child: _buildPartyStatus(
                    role: 'Técnico',
                    confirmed: techConfirmed,
                    isCurrentUser: !isClient,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Clarification text
          Text(
            clientConfirmed && techConfirmed
                ? '✅ Ambas partes han confirmado. Transición oficial completada.'
                : '⏳ Para transicionar el estado, ambas partes deben confirmar la misma acción.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 14),

          // Finalized State: Warranty and Payment Shield
          if (currentStatus == 'finalizado') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14291B) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: AppColors.success, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🛡️ Garantía Reparatutti 30 Días ACTIVA',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          'Pago liberado vía MercadoPago Escrow. Certificado: REP-30D-2026',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (currentStatus == 'pendiente_de_aceptacion' && !userHasConfirmed) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onConfirmAgendado,
                icon: const Icon(Icons.event_available_rounded, size: 18),
                label: const Text('Confirmar Agendamiento', style: TextStyle(fontSize: 14)),
              ),
            ),
          ] else if (currentStatus == 'agendado') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onConfirmCancelado,
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                    label: const Text('Cancelar', style: TextStyle(color: AppColors.danger, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onConfirmFinalizado,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: Text(
                      isClient ? 'Pagar y Finalizar' : 'Confirmar Fin',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (userHasConfirmed && (!clientConfirmed || !techConfirmed)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_bottom_rounded, size: 16, color: AppColors.mustardLight),
                  SizedBox(width: 8),
                  Text(
                    'Tu confirmación fue enviada. Esperando a la otra parte...',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartyStatus({
    required String role,
    required bool confirmed,
    required bool isCurrentUser,
    required bool isDark,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              role,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                color: isCurrentUser
                    ? (isDark ? AppColors.mustardDark : AppColors.mustardLight)
                    : null,
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 4),
              const Text('(Tú)', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              confirmed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: confirmed ? AppColors.success : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              confirmed ? 'Confirmado' : 'Pendiente',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: confirmed ? AppColors.success : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
