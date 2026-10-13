import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TriageInferenceData {
  final String category;
  final String serviceName;
  final double averagePrice;
  final double minPrice;
  final double maxPrice;
  final IconData icon;

  const TriageInferenceData({
    required this.category,
    required this.serviceName,
    required this.averagePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.icon,
  });
}

class SmartTriageInput extends StatefulWidget {
  final Function(String title, String category, double estimatedPrice) onRequestCreated;

  const SmartTriageInput({
    super.key,
    required this.onRequestCreated,
  });

  @override
  State<SmartTriageInput> createState() => SmartTriageInputState();
}

class SmartTriageInputState extends State<SmartTriageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  TriageInferenceData? _currentInference;
  bool _isAnalyzing = false;

  final List<String> _quickSuggestions = [
    'Gotea la canilla',
    'Destapar cañería',
    'Salta la térmica',
    'No enciende calefón',
    'Pintar habitación',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Public method to set text from external benchmark cards
  void setQueryText(String text) {
    _controller.text = text;
    _runInference(text);
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _currentInference = null;
        _isAnalyzing = false;
      });
      return;
    }

    setState(() => _isAnalyzing = true);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _runInference(text);
    });
  }

  void _runInference(String text) {
    final lower = text.toLowerCase();
    TriageInferenceData? data;

    if (lower.contains('canilla') ||
        lower.contains('gotea') ||
        lower.contains('grifo') ||
        lower.contains('cuerito') ||
        lower.contains('monocomando')) {
      data = const TriageInferenceData(
        category: 'Plomería',
        serviceName: 'Reparación de canilla / Grifería',
        averagePrice: 28000.0,
        minPrice: 20000.0,
        maxPrice: 38000.0,
        icon: Icons.water_drop_rounded,
      );
    } else if (lower.contains('cañeria') ||
        lower.contains('cañería') ||
        lower.contains('destapar') ||
        lower.contains('cloaca') ||
        lower.contains('inodoro') ||
        lower.contains('desague') ||
        lower.contains('desagüe')) {
      data = const TriageInferenceData(
        category: 'Plomería',
        serviceName: 'Destapar cañería / Desagote',
        averagePrice: 40000.0,
        minPrice: 30000.0,
        maxPrice: 55000.0,
        icon: Icons.plumbing_rounded,
      );
    } else if (lower.contains('termica') ||
        lower.contains('térmica') ||
        lower.contains('disyuntor') ||
        lower.contains('corte de luz') ||
        lower.contains('tablero') ||
        lower.contains('salta')) {
      data = const TriageInferenceData(
        category: 'Electricidad',
        serviceName: 'Cambio de disyuntor / Térmica',
        averagePrice: 32000.0,
        minPrice: 24000.0,
        maxPrice: 46000.0,
        icon: Icons.bolt_rounded,
      );
    } else if (lower.contains('luz') ||
        lower.contains('lampara') ||
        lower.contains('lámpara') ||
        lower.contains('ventilador') ||
        lower.contains('enchufe')) {
      data = const TriageInferenceData(
        category: 'Electricidad',
        serviceName: 'Instalación luminaria o tomacorriente',
        averagePrice: 26000.0,
        minPrice: 18000.0,
        maxPrice: 38000.0,
        icon: Icons.lightbulb_rounded,
      );
    } else if (lower.contains('calefon') ||
        lower.contains('calefón') ||
        lower.contains('termotanque') ||
        lower.contains('estufa') ||
        lower.contains('gas') ||
        lower.contains('piloto')) {
      data = const TriageInferenceData(
        category: 'Gas',
        serviceName: 'Revisión por gasista matriculado',
        averagePrice: 45000.0,
        minPrice: 35000.0,
        maxPrice: 60000.0,
        icon: Icons.local_fire_department_rounded,
      );
    } else if (lower.contains('pintar') ||
        lower.contains('pintura') ||
        lower.contains('pared') ||
        lower.contains('humedad')) {
      data = const TriageInferenceData(
        category: 'Pintura',
        serviceName: 'Pintura de ambiente estándar',
        averagePrice: 75000.0,
        minPrice: 60000.0,
        maxPrice: 98000.0,
        icon: Icons.format_paint_rounded,
      );
    } else if (lower.contains('flete') ||
        lower.contains('mudanza') ||
        lower.contains('mueble') ||
        lower.contains('traslado')) {
      data = const TriageInferenceData(
        category: 'Flete',
        serviceName: 'Flete urbano con carga',
        averagePrice: 38000.0,
        minPrice: 28000.0,
        maxPrice: 50000.0,
        icon: Icons.local_shipping_rounded,
      );
    } else {
      // General fallback
      data = const TriageInferenceData(
        category: 'Reparación Edilicia',
        serviceName: 'Mantenimiento integral del hogar',
        averagePrice: 30000.0,
        minPrice: 20000.0,
        maxPrice: 45000.0,
        icon: Icons.home_repair_service_rounded,
      );
    }

    if (mounted) {
      setState(() {
        _currentInference = data;
        _isAnalyzing = false;
      });
    }
  }

  void _submitRequest() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final inference = _currentInference ??
        const TriageInferenceData(
          category: 'Plomería',
          serviceName: 'Servicio general',
          averagePrice: 28000.0,
          minPrice: 20000.0,
          maxPrice: 38000.0,
          icon: Icons.handyman_rounded,
        );

    widget.onRequestCreated(title, inference.category, inference.averagePrice);
    _controller.clear();
    setState(() => _currentInference = null);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Triage Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.mustardLight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.mustardLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Triage • Diagnóstico Rápido',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      '¿Qué necesitas arreglar hoy?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Central Smart Input Box
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? (isDark ? AppColors.mustardDark : AppColors.mustardLight)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                hintText: 'Ej: Gotea la canilla, salta la térmica...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.mustardLight,
                  size: 22,
                ),
                suffixIcon: _isAnalyzing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mustardLight),
                        ),
                      )
                    : _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _currentInference = null);
                            },
                          )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: (_) => _submitRequest(),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Chip Suggestions
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickSuggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = _quickSuggestions[index];
                return InkWell(
                  onTap: () => setQueryText(suggestion),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242424) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Dynamic AI Prediction Card (Revealed when text is typed)
          if (_currentInference != null) ...[
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2A2210), const Color(0xFF1E1E1E)]
                      : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF6B5317) : const Color(0xFFFCD34D),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Category Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.mustardLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_currentInference!.icon, size: 14, color: AppColors.pureBlack),
                            const SizedBox(width: 5),
                            Text(
                              _currentInference!.category,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.pureBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // AI confidence label
                      Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 14,
                            color: isDark ? AppColors.accentYellow : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Sugerencia Automática',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.accentYellow : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _currentInference!.serviceName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Benchmark Average Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Precio Promedio Estimado:',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '~\$${_currentInference!.averagePrice.toStringAsFixed(0)} ARS',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.accentYellow : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rango de referencia: \$${_currentInference!.minPrice.toStringAsFixed(0)} - \$${_currentInference!.maxPrice.toStringAsFixed(0)} ARS',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mustardLight,
                        foregroundColor: AppColors.pureBlack,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _submitRequest,
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: Text(
                        'Publicar con Precio Sugerido (\$${_currentInference!.averagePrice.toStringAsFixed(0)})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
