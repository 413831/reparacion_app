import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class QuickRequestWizardModal extends StatefulWidget {
  final Function(Map<String, dynamic> jobData) onJobCreated;

  const QuickRequestWizardModal({
    super.key,
    required this.onJobCreated,
  });

  static void show(BuildContext context, Function(Map<String, dynamic> jobData) onCreated) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickRequestWizardModal(onJobCreated: onCreated),
    );
  }

  @override
  State<QuickRequestWizardModal> createState() => _QuickRequestWizardModalState();
}

class _QuickRequestWizardModalState extends State<QuickRequestWizardModal> {
  int _currentStep = 0; // 0: Categoría, 1: Descripción, 2: Fecha Preferida

  String? _selectedCategory;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTimeSlot = 'Mañana (09:00 - 13:00 hs)';
  bool _mockPhotoAttached = false;

  final List<Map<String, dynamic>> _trades = [
    {'name': 'Electricidad', 'icon': Icons.bolt_rounded},
    {'name': 'Pintura', 'icon': Icons.format_paint_rounded},
    {'name': 'Gas', 'icon': Icons.local_fire_department_rounded},
    {'name': 'Construcción', 'icon': Icons.handyman_rounded},
    {'name': 'Flete', 'icon': Icons.local_shipping_rounded},
    {'name': 'Reparación Edilicia', 'icon': Icons.home_repair_service_rounded},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onJobCreated({
      'category': _selectedCategory ?? 'Electricidad',
      'title': _titleController.text.trim().isEmpty ? 'Solicitud de $_selectedCategory' : _titleController.text.trim(),
      'description': _descController.text.trim(),
      'scheduled_date': _selectedDate,
      'time_slot': _selectedTimeSlot,
      'photos': _mockPhotoAttached ? ['photo_mock_1.jpg'] : [],
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Step Indicator & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Paso ${_currentStep + 1} de 3',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentStep == 0
                          ? 'Elegí el Oficio'
                          : _currentStep == 1
                              ? 'Detalle del Problema'
                              : 'Fecha Preferida',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / 3.0,
              backgroundColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
              color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 20),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                child: _currentStep == 0
                    ? _buildStep1Category(isDark)
                    : _currentStep == 1
                        ? _buildStep2Description(isDark)
                        : _buildStep3Schedule(isDark),
              ),
            ),

            // Bottom Navigation Buttons
            const SizedBox(height: 16),
            Row(
              children: [
                if (_currentStep > 0) ...[
                  OutlinedButton(
                    onPressed: () => setState(() => _currentStep--),
                    child: const Text('Atrás'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentStep == 0) {
                        if (_selectedCategory == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor, selecciona un oficio.')),
                          );
                          return;
                        }
                        setState(() => _currentStep = 1);
                      } else if (_currentStep == 1) {
                        if (_descController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor, describe brevemente el trabajo.')),
                          );
                          return;
                        }
                        setState(() => _currentStep = 2);
                      } else {
                        _submit();
                      }
                    },
                    child: Text(_currentStep == 2 ? 'Confirmar y Publicar Trabajo' : 'Siguiente'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Category(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué tipo de trabajo necesitás resolver?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: _trades.length,
          itemBuilder: (context, index) {
            final trade = _trades[index];
            final isSelected = _selectedCategory == trade['name'];
            return InkWell(
              onTap: () => setState(() => _selectedCategory = trade['name']),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.15)
                      : (isDark ? AppColors.cardDark : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? AppColors.mustardDark : AppColors.mustardLight)
                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      trade['icon'] as IconData,
                      size: 28,
                      color: isSelected
                          ? (isDark ? AppColors.mustardDark : AppColors.mustardLight)
                          : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trade['name'] as String,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep2Description(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalles de la solicitud ($_selectedCategory)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Título breve (ej. Reparación de fuga en baño)',
            prefixIcon: Icon(Icons.title_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Descripción detallada del arreglo',
            hintText: 'Explicá qué falla, si tenés materiales comprados o si hace falta diagnóstico previo...',
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () {
            setState(() => _mockPhotoAttached = !_mockPhotoAttached);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _mockPhotoAttached ? AppColors.success : (isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _mockPhotoAttached ? Icons.check_circle_rounded : Icons.add_a_photo_outlined,
                  color: _mockPhotoAttached ? AppColors.success : AppColors.mustardLight,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _mockPhotoAttached ? 'Foto del tablero/arreglo adjunta (1)' : 'Adjuntar fotos del problema (Opcional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _mockPhotoAttached ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Schedule(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cuándo te conviene recibir al técnico?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.mustardLight),
                  const SizedBox(width: 12),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: const Text('Cambiar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Franja horaria preferida:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _selectedTimeSlot,
          onChanged: (val) {
            if (val != null) setState(() => _selectedTimeSlot = val);
          },
          child: Column(
            children: ['Mañana (09:00 - 13:00 hs)', 'Tarde (13:00 - 18:00 hs)', 'Flexible durante el día'].map((slot) {
              return RadioListTile<String>(
                value: slot,
                activeColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                contentPadding: EdgeInsets.zero,
                title: Text(slot, style: const TextStyle(fontSize: 13.5)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
