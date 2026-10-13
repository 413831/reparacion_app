import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/account_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';

class AppDrawer extends ConsumerWidget {
  final bool isTechnician;
  final VoidCallback onToggleRole;
  final Function(String category)? onSelectTradeFilter;

  const AppDrawer({
    super.key,
    required this.isTechnician,
    required this.onToggleRole,
    this.onSelectTradeFilter,
  });

  void _showProfileModal(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Perfil de Usuario',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // User Card
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.2),
                    child: Icon(
                      isTechnician ? Icons.engineering_rounded : Icons.person_rounded,
                      size: 34,
                      color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTechnician ? 'Carlos Benítez' : 'Lucía Fernández',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          isTechnician ? 'tecnico.verificado@reparatutti.com' : 'cliente@reparatutti.com',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                            SizedBox(width: 4),
                            Text('Identidad KYC Verificada', style: TextStyle(fontSize: 12, color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scoring / Puntuación promedio (VISIBLE SOLO PARA TÉCNICOS)
              if (isTechnician) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2410) : const Color(0xFFFEF9C3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF4C3B12) : const Color(0xFFFDE047),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scoring / Calificación Promedio:', style: TextStyle(fontSize: 12, color: Colors.black87)),
                          Text('Fórmula acumulativa verificada', style: TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                      Row(
                        children: const [
                          Icon(Icons.star_rounded, size: 22, color: Color(0xFFB45309)),
                          SizedBox(width: 4),
                          Text(
                            '4.85 / 5.00',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Contadores y acceso a los 4 estados de trabajos
              const Text(
                'Estados de Trabajos',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatusCounterCard('Pendiente', '2', AppColors.warning, isDark),
                  const SizedBox(width: 8),
                  _buildStatusCounterCard('Agendado', '1', AppColors.info, isDark),
                  const SizedBox(width: 8),
                  _buildStatusCounterCard('Finalizado', '14', AppColors.success, isDark),
                  const SizedBox(width: 8),
                  _buildStatusCounterCard('Cancelado', '0', AppColors.danger, isDark),
                ],
              ),
              const SizedBox(height: 20),

              // Términos y Condiciones Legales (Placeholder genérico requerido)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined, color: AppColors.mustardLight),
                title: const Text('Términos y Condiciones Vigentes', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text('[CONFIG_TERMINOS_Y_CONDICIONES_LEGALES]', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/terms');
                },
              ),
              const Spacer(),

              // Botón de Eliminación de cuenta (Mandatorio para Apple App Store & Google Play)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showAccountSecurityDialog(context, ref);
                  },
                  icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 18),
                  label: const Text('Eliminar Cuenta (App Store & GDPR)', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountSecurityDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Gestión de Cuenta'),
          ],
        ),
        content: const Text(
          'Conforme a las directrices de Apple App Store (Guideline 5.1.1) y Google Play Data Safety:\n\n'
          '• Suspender cuenta: Desactiva tu perfil temporalmente. Podés reactivarlo contactando a soporte.\n\n'
          '• Eliminar cuenta: Anonimiza y purga definitivamente tus datos personales, direcciones y credenciales de acceso tanto del servidor como del dispositivo.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(accountServiceProvider).suspendAccount();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cuenta suspendida con éxito. Sesión cerrada.')),
                );
                context.go('/login');
              }
            },
            child: const Text('Suspender'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              _confirmDeleteAccountFlow(context, ref);
            },
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccountFlow(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Confirmar Eliminación'),
          ],
        ),
        content: const Text(
          '¿Estás seguro/a de que deseas eliminar tu cuenta?\n\n'
          'Esta acción es IRREVERSIBLE. Tus datos personales y de contacto serán eliminados y anonimizados de inmediato en cumplimiento de GDPR y las normativas de la App Store.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();

              // Trigger backend deletion & session wipe
              await ref.read(accountServiceProvider).deleteAccount();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cuenta eliminada y anonimizada. Tu sesión ha sido cerrada.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
                // Redirect user to login screen
                context.go('/login');
              }
            },
            child: const Text('Sí, Eliminar Cuenta'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Centro de Notificaciones',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Text(
                    'Configurá los canales multicanal para recibir recordatorios de agenda (24h y 2h antes):',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Notificaciones Push', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Alertas directas en la pantalla de bloqueo'),
                    value: true,
                    activeThumbColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    onChanged: (val) {},
                  ),
                  SwitchListTile(
                    title: const Text('Correo Electrónico', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Confirmaciones y recibos detallados'),
                    value: true,
                    activeThumbColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    onChanged: (val) {},
                  ),
                  SwitchListTile(
                    title: const Text('Mensajes SMS', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Alertas críticas en caso de no tener datos'),
                    value: false,
                    activeThumbColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    onChanged: (val) {},
                  ),
                  SwitchListTile(
                    title: const Text('Recordatorios de Agenda (24 h y 2 h)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Avisos preventivos hacia ambas partes'),
                    value: true,
                    activeThumbColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    onChanged: (val) {},
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMessagesInboxModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bandeja de Mensajes 1:1',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Filtros por Estado y por Fecha
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: 'Todos los Estados',
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por Estado',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos los Estados', child: Text('Todos los Estados', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'agendado', child: Text('Agendados', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'pendiente_de_aceptacion', child: Text('Pendientes', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'finalizado', child: Text('Finalizados', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list_rounded, size: 16),
                    label: const Text('Por Fecha', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Active Chat Item
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.2),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.mustardLight, size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isTechnician ? 'Lucía Fernández (Cliente)' : 'Carlos Benítez (Técnico)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('agendado', style: TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  subtitle: const Text('¿Me compartís la dirección exacta? • Hoy 14:30', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/chat/44444444-4444-4444-4444-444444444444');
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildStatusCounterCard(String label, String count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : Colors.grey[700]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.2),
                child: Icon(
                  isTechnician ? Icons.engineering_rounded : Icons.person_rounded,
                  color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                  size: 32,
                ),
              ),
              accountName: Text(
                isTechnician ? 'Carlos Benítez (Técnico)' : 'Lucía Fernández (Cliente)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              accountEmail: Text(
                isTechnician ? 'Scoring: 4.85 ★ • Verificado' : 'cliente@reparatutti.com',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ),

            // Mode switcher toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isTechnician ? 'Modo Técnico Activo' : 'Modo Cliente Activo',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  Switch(
                    value: isTechnician,
                    activeThumbColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    onChanged: (_) => onToggleRole(),
                  ),
                ],
              ),
            ),
            const Divider(),

            // 1. TRABAJOS (Visible ONLY for Técnicos)
            if (isTechnician) ...[
              ListTile(
                leading: const Icon(Icons.handyman_rounded, color: AppColors.mustardLight),
                title: const Text('Trabajos Disponibles', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Feed segmentado por oficio con búsqueda'),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],

            // 2. PERFIL DE USUARIO
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Perfil de Usuario'),
              subtitle: Text(isTechnician ? 'Scoring, estados y gestión' : 'Datos y estados'),
              onTap: () {
                Navigator.of(context).pop();
                _showProfileModal(context, ref);
              },
            ),

            // 3. NOTIFICACIONES
            ListTile(
              leading: const Icon(Icons.notifications_none_rounded),
              title: const Text('Notificaciones'),
              subtitle: const Text('Canales Push, Mail, SMS y recordatorios'),
              onTap: () {
                Navigator.of(context).pop();
                _showNotificationsModal(context);
              },
            ),

            // 4. MENSAJES
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Mensajes'),
              subtitle: const Text('Bandeja filtrada con dirección compartida'),
              onTap: () {
                Navigator.of(context).pop();
                _showMessagesInboxModal(context);
              },
            ),

            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Validación KYC Biométrica'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/kyc?role=${isTechnician ? "technician" : "client"}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(secureStorageServiceProvider).clearAuthSession();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
