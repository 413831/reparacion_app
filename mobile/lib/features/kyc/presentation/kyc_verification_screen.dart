import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum KYCVisualState {
  unverified,
  capturing,
  pending,
  verified,
  rejected,
}

class KYCVerificationScreen extends StatefulWidget {
  final bool isTechnician;

  const KYCVerificationScreen({
    super.key,
    this.isTechnician = true,
  });

  @override
  State<KYCVerificationScreen> createState() => _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends State<KYCVerificationScreen> {
  KYCVisualState _state = KYCVisualState.unverified;
  int _activeCaptureStep = 0; // 0: DNI Frente, 1: DNI Dorso, 2: Selfie Facial

  bool _dniFrontCaptured = false;
  bool _dniBackCaptured = false;
  bool _selfieCaptured = false;

  void _startCapture() {
    setState(() {
      _state = KYCVisualState.capturing;
      _activeCaptureStep = 0;
    });
  }

  void _mockCaptureStep() {
    setState(() {
      if (widget.isTechnician) {
        if (_activeCaptureStep == 0) {
          _dniFrontCaptured = true;
          _activeCaptureStep = 1;
        } else if (_activeCaptureStep == 1) {
          _dniBackCaptured = true;
          _activeCaptureStep = 2;
        } else if (_activeCaptureStep == 2) {
          _selfieCaptured = true;
          _submitMockKYC();
        }
      } else {
        // Client: only selfie facial biometrics
        _selfieCaptured = true;
        _submitMockKYC();
      }
    });
  }

  void _submitMockKYC() {
    setState(() {
      _state = KYCVisualState.pending;
    });

    // Simulate async KYC API call to Renaper / Rekognition
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _state = KYCVisualState.verified;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validación de Identidad (KYC)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRoleBadge(),
              const SizedBox(height: 16),
              if (_state == KYCVisualState.unverified) _buildUnverifiedView(isDark),
              if (_state == KYCVisualState.capturing) _buildCaptureView(isDark),
              if (_state == KYCVisualState.pending) _buildPendingView(isDark),
              if (_state == KYCVisualState.verified) _buildVerifiedView(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isTechnician ? Icons.engineering_rounded : Icons.person_rounded,
            size: 16,
            color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
          ),
          const SizedBox(width: 6),
          Text(
            widget.isTechnician
                ? 'Perfil: Técnico (Requiere DNI + Biometría)'
                : 'Perfil: Cliente (Requiere Selfie Facial)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildUnverifiedView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Valida tu identidad para comenzar a operar',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isTechnician
              ? 'Por normativas de seguridad, los técnicos deben validar DNI argentino y prueba de vida facial antes de postularse a presupuestos.'
              : 'Verifica tu rostro con una selfie en segundos para enviar y recibir solicitudes seguras.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        _buildRequirementItem(
          icon: Icons.credit_card_rounded,
          title: 'DNI Físico (Frente y Dorso)',
          subtitle: widget.isTechnician ? 'Obligatorio para técnicos' : 'No requerido para clientes',
          active: widget.isTechnician,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildRequirementItem(
          icon: Icons.face_retouching_natural_rounded,
          title: 'Prueba de Vida Facial (Selfie)',
          subtitle: 'Validación biométrica contra RENAPER',
          active: true,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildRequirementItem(
          icon: Icons.lock_outline_rounded,
          title: 'Cifrado de Extremo a Extremo',
          subtitle: 'Protegido por la Ley 25.326 de Protección de Datos',
          active: true,
          isDark: isDark,
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startCapture,
            child: const Text('Iniciar Verificación Biométrica'),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptureView(bool isDark) {
    String stepTitle = '';
    String stepHint = '';
    IconData stepIcon = Icons.camera_alt_outlined;

    if (widget.isTechnician) {
      if (_activeCaptureStep == 0) {
        stepTitle = 'Paso 1 de 3: DNI Frente';
        stepHint = 'Enfocá el frente de tu DNI dentro del recuadro con buena iluminación.';
        stepIcon = Icons.badge_outlined;
      } else if (_activeCaptureStep == 1) {
        stepTitle = 'Paso 2 de 3: DNI Dorso';
        stepHint = 'Girá tu DNI y enfocá el dorso asegurando que el código de barras sea visible.';
        stepIcon = Icons.credit_card_rounded;
      } else {
        stepTitle = 'Paso 3 de 3: Selfie con Prueba de Vida';
        stepHint = 'Mantené la mirada fija y una expresión neutra dentro del óvalo.';
        stepIcon = Icons.face_rounded;
      }
    } else {
      stepTitle = 'Selfie Facial';
      stepHint = 'Mantené la mirada fija y una expresión neutra dentro del óvalo.';
      stepIcon = Icons.face_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stepTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          stepHint,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.isTechnician)
          Row(
            children: [
              _buildStepPill('1. Frente', _dniFrontCaptured, isDark),
              const SizedBox(width: 8),
              _buildStepPill('2. Dorso', _dniBackCaptured, isDark),
              const SizedBox(width: 8),
              _buildStepPill('3. Selfie', _selfieCaptured, isDark),
            ],
          ),
        const SizedBox(height: 20),

        // Simulated Camera Viewfinder
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161616) : const Color(0xFF202020),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Frame guides
              Container(
                width: _activeCaptureStep == 2 || !widget.isTechnician ? 180 : 250,
                height: _activeCaptureStep == 2 || !widget.isTechnician ? 240 : 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    _activeCaptureStep == 2 || !widget.isTechnician ? 120 : 16,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    stepIcon,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Simulador de Cámara Activo',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _mockCaptureStep,
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(_activeCaptureStep == 2 || !widget.isTechnician
                ? 'Capturar y Enviar Biometría'
                : 'Capturar y Siguiente'),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Validación en Proceso',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Estamos contrastando los datos con los registros oficiales de RENAPER y evaluando la biometría facial.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 18, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text(
                    'Estado: Pending (Simulando respuesta)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.verified_rounded,
                  size: 56,
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '¡Identidad Verificada con Éxito!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isTechnician
                  ? 'Tu perfil de técnico ha sido validado correctamente. Tu insignia de verificación ya es visible y estás habilitado para postularte a solicitudes.'
                  : 'Tu identidad de cliente ha sido verificada con biometría facial.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Metrics Card
            Container(
              width: double.infinity,
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
                  _buildMetricRow('Proveedor', 'RENAPER Biometrics Mock'),
                  const Divider(height: 20),
                  _buildMetricRow('Coincidencia Facial', '98.7% (Aprobado)'),
                  const Divider(height: 20),
                  _buildMetricRow('Prueba de Vida (Liveness)', 'Exitosa'),
                  const Divider(height: 20),
                  _buildMetricRow('Estado de Postulación', 'Habilitado'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Volver a la Aplicación'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildRequirementItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepPill(String title, bool captured, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: captured
            ? AppColors.success.withValues(alpha: 0.15)
            : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: captured
              ? AppColors.success
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            captured ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: captured ? AppColors.success : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: captured ? FontWeight.bold : FontWeight.normal,
              color: captured ? AppColors.success : null,
            ),
          ),
        ],
      ),
    );
  }
}
