import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../navigation/presentation/app_drawer.dart';
import '../../jobs/presentation/widgets/job_status_action_card.dart';
import '../../jobs/presentation/widgets/job_summary_card.dart';
import '../../jobs/presentation/widgets/quick_request_wizard_modal.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _isTechnician = false;
  bool _isLoading = false;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // State machine simulation for double confirmation
  String _jobStatus = 'pendiente_de_aceptacion';
  bool _clientConfirmed = false;
  bool _techConfirmed = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Todos', 'icon': Icons.apps_rounded},
    {'name': 'Electricidad', 'icon': Icons.bolt_rounded},
    {'name': 'Pintura', 'icon': Icons.format_paint_rounded},
    {'name': 'Gas', 'icon': Icons.local_fire_department_rounded},
    {'name': 'Construcción', 'icon': Icons.handyman_rounded},
    {'name': 'Flete', 'icon': Icons.local_shipping_rounded},
    {'name': 'Reparación Edilicia', 'icon': Icons.home_repair_service_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerRefreshSimulation() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _openQuickRequestWizard() {
    QuickRequestWizardModal.show(context, (jobData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Trabajo "${jobData['title']}" publicado exitosamente!'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() {
        _jobStatus = 'pendiente_de_aceptacion';
        _clientConfirmed = false;
        _techConfirmed = false;
      });
    });
  }

  void _handleConfirmStatus(String targetStatus) {
    setState(() {
      if (_isTechnician) {
        _techConfirmed = true;
      } else {
        _clientConfirmed = true;
      }

      // Check double confirmation rule
      if (_clientConfirmed && _techConfirmed) {
        _jobStatus = targetStatus;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Doble confirmación exitosa! Estado global actualizado a: $targetStatus'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirmación registrada. Esperando a la otra parte para actualizar.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: AppDrawer(
        isTechnician: _isTechnician,
        onToggleRole: () {
          setState(() => _isTechnician = !_isTechnician);
        },
      ),
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: Text(
                _isTechnician ? 'Reparatutti Pro' : 'Reparatutti',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Simular Shimmer',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _triggerRefreshSimulation,
          ),
          IconButton(
            tooltip: 'Alternar Rol',
            icon: Icon(_isTechnician ? Icons.engineering_rounded : Icons.person_rounded),
            onPressed: () {
              setState(() => _isTechnician = !_isTechnician);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // Mode Banner
            _buildModeBanner(isDark),
            const SizedBox(height: 12),

            // CLIENT VIEW vs TECHNICIAN VIEW
            if (!_isTechnician) ...[
              _buildClientHomeView(isDark),
            ] else ...[
              _buildTechnicianHomeView(isDark),
            ],

            const SizedBox(height: 16),

            // Interactive Double Confirmation Card Demonstration
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Orden en Curso: Instalación de disyuntor',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            JobStatusActionCard(
              currentStatus: _jobStatus,
              isClient: !_isTechnician,
              clientConfirmed: _clientConfirmed,
              techConfirmed: _techConfirmed,
              onConfirmAgendado: () => _handleConfirmStatus('agendado'),
              onConfirmFinalizado: () => _handleConfirmStatus('finalizado'),
              onConfirmCancelado: () => _handleConfirmStatus('cancelado'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(
            _isTechnician ? Icons.engineering_rounded : Icons.home_repair_service_rounded,
            size: 20,
            color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isTechnician
                  ? 'Modo Técnico: Descubrí solicitudes y respondé cotizaciones'
                  : 'Modo Cliente: Agendá reparaciones en 3 simples pasos',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CLIENTE: Foco 100% en agendamiento ultra rápido
  // ==========================================================================
  Widget _buildClientHomeView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prominent CTA "Pedir trabajo"
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF332608), const Color(0xFF1F1A07)]
                  : [const Color(0xFFFEF3C7), const Color(0xFFFFFBEB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF664D10) : const Color(0xFFFDE68A),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Necesitás una reparación en tu hogar?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Publicá tu solicitud y recibí presupuestos de técnicos verificados en minutos.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openQuickRequestWizard,
                      icon: const Icon(Icons.add_task_rounded, size: 20),
                      label: const Text('Pedir trabajo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      _showAgendaDialog(context);
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: const Text('Agenda'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TÉCNICO: Foco en responder y atender demanda
  // ==========================================================================
  Widget _buildTechnicianHomeView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shortcuts: "Agenda" y "Chats" activos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showAgendaDialog(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.mustardLight, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Mi Agenda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('1 programado', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/chat/44444444-4444-4444-4444-444444444444'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.mustardLight, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Chats Activos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Responder al instante', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Search Bar in real time
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar trabajos por palabra clave o zona...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val);
            },
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Category Chips
        SizedBox(
          height: 38,
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
                    Icon(cat['icon'] as IconData, size: 14),
                    const SizedBox(width: 4),
                    Text(cat['name'] as String),
                  ],
                ),
                selected: isSelected,
                selectedColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.pureBlack : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _selectedCategory = cat['name'] as String),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Available Job Feed Item
        if (_isLoading) ...[
          const JobCardSkeleton(),
        ] else ...[
          JobSummaryCard(
            tradeTitle: 'Instalación de disyuntor y recableado',
            status: 'agendado',
            scheduledDateText: 'Martes 14 Oct • 10:00 hs',
            addressText: 'Honduras 4820, Palermo Soho, CABA',
            budgetEstimateText: r'$45.000',
            actionButtonText: 'Aceptar Trabajo',
            onActionPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trabajo aceptado exitosamente.')),
              );
            },
          ),
        ],
      ],
    );
  }

  void _showAgendaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: AppColors.mustardLight),
            SizedBox(width: 8),
            Text('Agenda Sincronizada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Próximos Trabajos Agendados:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instalación de disyuntor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Fecha: Mañana a las 10:00 hs', style: TextStyle(fontSize: 12)),
                  Text('Estado: agendado (Doble confirmación OK)', style: TextStyle(fontSize: 11, color: AppColors.info)),
                  SizedBox(height: 6),
                  Text('🔔 Recordatorios programados: 24h antes y 2h antes', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
