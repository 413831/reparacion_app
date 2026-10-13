import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../navigation/presentation/app_drawer.dart';
import '../../jobs/presentation/widgets/job_status_action_card.dart';
import '../../jobs/presentation/widgets/payment_guarantee_bottom_sheet.dart';
import '../../jobs/presentation/widgets/quick_request_wizard_modal.dart';
import 'widgets/smart_triage_input.dart';
import 'widgets/benchmark_price_card.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final GlobalKey<SmartTriageInputState> _smartTriageKey = GlobalKey<SmartTriageInputState>();

  bool _isTechnician = false;
  bool _isLoading = false;
  String _selectedCategory = 'Todos';

  // State machine simulation for double confirmation
  String _jobStatus = 'pendiente_de_aceptacion';
  bool _clientConfirmed = false;
  bool _techConfirmed = false;
  double _activeJobPrice = 28000.0;
  String _activeJobTitle = 'Reparación de canilla / Grifería';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Todos', 'icon': Icons.apps_rounded},
    {'name': 'Plomería', 'icon': Icons.water_drop_rounded},
    {'name': 'Electricidad', 'icon': Icons.bolt_rounded},
    {'name': 'Pintura', 'icon': Icons.format_paint_rounded},
    {'name': 'Gas', 'icon': Icons.local_fire_department_rounded},
    {'name': 'Construcción', 'icon': Icons.handyman_rounded},
    {'name': 'Flete', 'icon': Icons.local_shipping_rounded},
    {'name': 'Reparación Edilicia', 'icon': Icons.home_repair_service_rounded},
  ];



  void _triggerRefreshSimulation() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _handleSmartRequestCreated(String title, String category, double estimatedPrice) {
    setState(() {
      _activeJobTitle = title;
      _activeJobPrice = estimatedPrice;
      _jobStatus = 'pendiente_de_aceptacion';
      _clientConfirmed = false;
      _techConfirmed = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Solicitud "$title" ($category) publicada con Precio Estimado de \$${estimatedPrice.toStringAsFixed(0)} ARS!',
          style: const TextStyle(fontSize: 13),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _openQuickRequestWizard() {
    QuickRequestWizardModal.show(context, (jobData) {
      setState(() {
        _activeJobTitle = jobData['title'] ?? 'Reparación en el hogar';
        _jobStatus = 'pendiente_de_aceptacion';
        _clientConfirmed = false;
        _techConfirmed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Trabajo "${jobData['title']}" publicado exitosamente!',
            style: const TextStyle(fontSize: 13),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    });
  }

  void _handleConfirmStatus(String targetStatus) {
    // If client is confirming 'finalizado', trigger the MercadoPago BottomSheet!
    if (!_isTechnician && targetStatus == 'finalizado' && !_clientConfirmed) {
      PaymentGuaranteeBottomSheet.show(
        context: context,
        amount: _activeJobPrice,
        technicianName: 'Carlos Benítez',
        jobTitle: _activeJobTitle,
        onPaymentConfirmed: () {
          _executeStatusConfirmation('finalizado');
        },
      );
      return;
    }

    _executeStatusConfirmation(targetStatus);
  }

  void _executeStatusConfirmation(String targetStatus) {
    setState(() {
      if (_isTechnician) {
        _techConfirmed = true;
      } else {
        _clientConfirmed = true;
      }

      // Check double confirmation rule
      if (_clientConfirmed && _techConfirmed) {
        _jobStatus = targetStatus;
        final isFin = targetStatus == 'finalizado';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFin
                  ? '¡Doble confirmación completada! Pago liberado y Garantía Reparatutti 30 Días ACTIVADA.'
                  : '¡Doble confirmación exitosa! Estado global actualizado a: $targetStatus',
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Confirmación registrada. Esperando a la otra parte para actualizar.',
              style: TextStyle(fontSize: 13),
            ),
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
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, fontSize: 18),
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
            tooltip: 'Alternar Rol (Cliente / Técnico)',
            icon: Icon(_isTechnician ? Icons.engineering_rounded : Icons.person_rounded),
            onPressed: () {
              setState(() => _isTechnician = !_isTechnician);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Mode Banner with quick switcher
            _buildModeBanner(isDark),
            const SizedBox(height: 10),

            // CLIENT VIEW vs TECHNICIAN VIEW
            if (!_isTechnician) ...[
              _buildClientHomeView(isDark),
            ] else ...[
              _buildTechnicianHomeView(isDark),
            ],

            const SizedBox(height: 16),

            // Active Order Section (Double Confirmation card)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Seguimiento en Vivo: $_activeJobTitle',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${_activeJobPrice.toStringAsFixed(0)} ARS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: isDark ? AppColors.accentYellow : AppColors.mustardLight,
                    ),
                  ),
                ],
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
            const SizedBox(height: 20),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(
            _isTechnician ? Icons.engineering_rounded : Icons.person_pin_rounded,
            size: 20,
            color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isTechnician
                  ? 'Modo Profesional: Descubrí trabajos y aplicá a precios sugeridos.'
                  : 'Modo Cliente: Smart Triage, precios promedio transparentes y garantía.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isTechnician = !_isTechnician),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _isTechnician ? 'Cambiar a Cliente' : 'Cambiar a Técnico',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CLIENT VIEW: Smart Triage Central + Benchmark Prices + Agenda
  // ==========================================================================
  Widget _buildClientHomeView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Central Smart Triage Input Component
        SmartTriageInput(
          key: _smartTriageKey,
          onRequestCreated: _handleSmartRequestCreated,
        ),
        const SizedBox(height: 12),

        // 2. Benchmark Average Price Cards List
        BenchmarkPriceCardList(
          onSelectPriceItem: (item) {
            _smartTriageKey.currentState?.setQueryText(item.title);
          },
        ),
        const SizedBox(height: 14),

        // 3. Quick Agenda & Wizard Access Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openQuickRequestWizard,
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Asistente Manual', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAgendaDialog(context),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: const Text('Ver Mi Agenda', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TECHNICIAN VIEW: Verified Shield + Instant Conversion Feed + 1:1 Chat
  // ==========================================================================
  Widget _buildTechnicianHomeView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Professional Verified Shield Header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF192518) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF047857) : const Color(0xFF86EFAC),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppColors.success, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text(
                          'Carlos Benítez',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '• Profesional Verificado',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: const [
                        Icon(Icons.star_rounded, size: 16, color: AppColors.accentYellow),
                        SizedBox(width: 2),
                        Text(
                          '4.85 / 5.00 (14 reseñas) • Plomería & Electricidad',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: AppColors.mustardLight, size: 20),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mi Agenda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('1 programado', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: AppColors.mustardLight, size: 20),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Chats Activos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Lucía Fernández (1)', style: TextStyle(fontSize: 13, color: Colors.grey)),
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

        // Category Filter Chips
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
                  fontSize: 13,
                ),
                onSelected: (_) => setState(() => _selectedCategory = cat['name'] as String),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Technician Feed: Available Jobs with Instant Accept vs Custom Proposal
        if (_isLoading) ...[
          const JobCardSkeleton(),
        ] else ...[
          // Job 1: Gotea la canilla (Smart Triage with Suggested Price)
          _buildAvailableJobCard(
            title: 'Gotea la canilla de la cocina',
            category: 'Plomería',
            locality: 'Belgrano, CABA',
            timeAgo: 'Hace 15 min',
            suggestedPrice: 28000.0,
            hasInstantAccept: true,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          // Job 2: Cambio de disyuntor
          _buildAvailableJobCard(
            title: 'Cambio de disyuntor diferencial',
            category: 'Electricidad',
            locality: 'Palermo Soho, CABA',
            timeAgo: 'Hace 45 min',
            suggestedPrice: 32000.0,
            hasInstantAccept: true,
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildAvailableJobCard({
    required String title,
    required String category,
    required String locality,
    required String timeAgo,
    required double suggestedPrice,
    required bool hasInstantAccept,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2412) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.accentYellow : const Color(0xFF92400E),
                  ),
                ),
              ),
              Text(
                timeAgo,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 15, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                locality,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Suggested Price Callout
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Precio Sugerido por Cliente:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  '\$${suggestedPrice.toStringAsFixed(0)} ARS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.accentYellow : AppColors.mustardLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Two Action Choices: Instant conversion vs Custom Quote
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Presupuesto a medida enviado para "$title".',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    );
                  },
                  child: const Text('Presupuesto a Medida', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mustardLight,
                    foregroundColor: AppColors.pureBlack,
                  ),
                  onPressed: () {
                    setState(() {
                      _activeJobTitle = title;
                      _activeJobPrice = suggestedPrice;
                      _jobStatus = 'agendado';
                      _techConfirmed = true;
                      _clientConfirmed = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '¡Aceptación instantánea confirmada! Estado actualizado a "Agendado".',
                          style: const TextStyle(fontSize: 13),
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text('Aceptar Sugerido', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
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
            Text('Agenda Sincronizada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_activeJobTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  const Text('Fecha: Mañana a las 10:00 hs', style: TextStyle(fontSize: 13)),
                  Text('Estado: $_jobStatus', style: const TextStyle(fontSize: 13, color: AppColors.info, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('🔔 Recordatorios preventivos programados: 24h y 2h antes', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
