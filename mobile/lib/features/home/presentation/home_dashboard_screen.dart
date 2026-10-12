import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shimmer_loader.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _isLoading = false;
  bool _isTechnician = false;
  String _selectedCategory = 'Todos';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Todos', 'icon': Icons.apps_rounded},
    {'name': 'Electricidad', 'icon': Icons.bolt_rounded},
    {'name': 'Pintura', 'icon': Icons.format_paint_rounded},
    {'name': 'Gas', 'icon': Icons.local_fire_department_rounded},
    {'name': 'Construcción', 'icon': Icons.handyman_rounded},
    {'name': 'Flete', 'icon': Icons.local_shipping_rounded},
    {'name': 'Reparación Edilicia', 'icon': Icons.home_repair_service_rounded},
  ];

  void _triggerRefreshSimulation() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.build_circle_rounded, color: AppColors.pureBlack, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'Reparatutti',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Simular Carga Shimmer',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _triggerRefreshSimulation,
          ),
          IconButton(
            tooltip: 'Términos Legales (Ley 25.326)',
            icon: const Icon(Icons.description_outlined),
            onPressed: () => context.push('/terms'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // User Role & KYC Switcher Card
            _buildRoleBanner(isDark),
            const SizedBox(height: 16),

            // Horizontal Trade Categories Filter
            _buildCategorySelector(isDark),
            const SizedBox(height: 16),

            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isTechnician ? 'Trabajos Disponibles para Presupuestar' : 'Mis Solicitudes Activas',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isLoading ? 'Cargando...' : '1 activo',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Feed Content (Shimmer vs Job Cards)
            if (_isLoading) ...[
              const JobCardSkeleton(),
              const JobCardSkeleton(),
            ] else ...[
              _buildSampleJobCard(isDark),
            ],

            const SizedBox(height: 24),
            // Quick Access Hub for Evaluation
            _buildQuickActionsCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.2),
                child: Icon(
                  _isTechnician ? Icons.engineering_rounded : Icons.person_rounded,
                  color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTechnician ? 'Modo Técnico (Carlos Benítez)' : 'Modo Cliente (Lucía Fernández)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    Row(
                      children: const [
                        Icon(Icons.verified, size: 13, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'KYC Verificado • Calificación 4.85 ★',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isTechnician,
                activeThumbColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                onChanged: (val) {
                  setState(() => _isTechnician = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat['name'];
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat['icon'] as IconData, size: 16),
                const SizedBox(width: 6),
                Text(cat['name'] as String),
              ],
            ),
            selected: isSelected,
            selectedColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
            labelStyle: TextStyle(
              color: isSelected
                  ? AppColors.pureBlack
                  : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12.5,
            ),
            onSelected: (_) {
              setState(() => _selectedCategory = cat['name'] as String);
            },
          );
        },
      ),
    );
  }

  Widget _buildSampleJobCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2410) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Electricidad',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mustardLight,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Asignado / En Curso',
                    style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Instalación de disyuntor y recableado de cocina',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Corte térmico frecuente al conectar horno eléctrico. Se necesita cambio de disyuntor diferencial y revisión térmica.',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('Palermo Soho, CABA', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                Spacer(),
                Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text('Mañana 10:00 hs', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Técnico Asignado:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text('Carlos Benítez (4.85 ★)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push('/chat/44444444-4444-4444-4444-444444444444'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Abrir Chat 1:1'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accesos Rápidos del MVP',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _buildActionTile(
            icon: Icons.shield_outlined,
            title: 'Verificación de Identidad (KYC)',
            subtitle: 'DNI frente/dorso + prueba de vida facial',
            onTap: () => context.push('/kyc?role=${_isTechnician ? "technician" : "client"}'),
          ),
          const Divider(height: 16),
          _buildActionTile(
            icon: Icons.gavel_rounded,
            title: 'Términos y Condiciones (Argentina)',
            subtitle: 'Ley 25.326 de Protección de Datos y Derechos ARCO',
            onTap: () => context.push('/terms'),
          ),
          const Divider(height: 16),
          _buildActionTile(
            icon: Icons.pin_drop_rounded,
            title: 'Chat 1:1 con Compartir Ubicación',
            subtitle: 'Mensajería y tarjeta con vista previa de mapa',
            onTap: () => context.push('/chat/44444444-4444-4444-4444-444444444444'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.mustardLight),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
