import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  final VoidCallback? onAccepted;

  const TermsAndConditionsScreen({
    super.key,
    this.onAccepted,
  });

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasReachedBottom = false;
  bool _acceptedTerms = false;
  bool _acceptedArco = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= (maxScroll - 80) && !_hasReachedBottom) {
      setState(() {
        _hasReachedBottom = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleAccept() {
    if (!_acceptedTerms || !_acceptedArco) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debe aceptar expresamente las cláusulas de Protección de Datos y Derechos ARCO para continuar.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Términos aceptados conforme a la Ley 25.326.'),
        backgroundColor: AppColors.success,
      ),
    );

    if (widget.onAccepted != null) {
      widget.onAccepted!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Privacidad Legal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: const Center(
              child: Text(
                'v1.0-AR',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Legal Banner Note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? const Color(0xFF2A2412) : const Color(0xFFFFFBEB),
              child: Row(
                children: [
                  Icon(
                    Icons.gavel_rounded,
                    color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Marco regulatorio: Ley 25.326 (Protección de Datos) y Ley 24.240 (Defensa del Consumidor - Rep. Argentina).',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Legal Text
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSectionHeader('1. Objeto y Funcionamiento de la Plataforma'),
                    _buildParagraph(
                      'Reparatutti es una plataforma tecnológica que conecta a usuarios clientes con técnicos profesionales independientes '
                      'en diversos oficios (Electricidad, Pintura, Gas, Construcción, Flete y Reparación Edilicia). Reparatutti no presta servicios directos '
                      'de mano de obra ni actúa como empleador de los técnicos.',
                    ),
                    const SizedBox(height: 20),

                    _buildSectionHeader('2. Protección de Datos Personales (Ley N° 25.326)'),
                    _buildParagraph(
                      'De conformidad con la Ley 25.326 de Protección de los Datos Personales de la República Argentina, los datos recabados '
                      '(incluyendo nombre, número de documento, correo electrónico, ubicación física y registros biométricos de verificación) '
                      'serán almacenados en bases seguras con cifrado en tránsito (TLS 1.3) y en reposo (AES-256).',
                    ),
                    _buildParagraph(
                      'La recolección de datos biométricos y documentación identitaria tiene como único fin garantizar la seguridad '
                      'de la comunidad y la validación KYC de los técnicos y clientes.',
                    ),
                    const SizedBox(height: 20),

                    _buildSectionHeader('3. Derechos ARCO (Acceso, Rectificación, Cancelación y Oposición)'),
                    _buildParagraph(
                      'El titular de los datos personales tiene la facultad de ejercer el derecho de acceso a los mismos en forma gratuita '
                      'a intervalos no inferiores a seis meses, salvo que se acredite un interés legítimo al efecto conforme lo establecido '
                      'en el artículo 14, inciso 3 de la Ley N° 25.326.',
                    ),
                    _buildParagraph(
                      'Para solicitar el acceso, rectificación, actualización o supresión de sus datos, podrá remitir una solicitud '
                      'fehaciente a soporte@reparatutti.com. La Agencia de Acceso a la Información Pública (AAIP) tiene la atribución de '
                      'atender denuncias relativas al incumplimiento de las normas sobre protección de datos.',
                    ),
                    const SizedBox(height: 20),

                    _buildSectionHeader('4. Defensa del Consumidor (Ley N° 24.240)'),
                    _buildParagraph(
                      'En cumplimiento con la Ley de Defensa del Consumidor (Ley 24.240), Reparatutti provee un canal transparente '
                      'de soporte, calificación recíproca con métricas públicas y mecanismos de reporte de conductas inapropiadas o '
                      'incumplimientos de presupuestos acordados entre partes.',
                    ),
                    const SizedBox(height: 20),

                    _buildSectionHeader('5. Privacidad de Ubicación en Tiempo Real'),
                    _buildParagraph(
                      'La dirección física exacta del cliente nunca es visible públicamente en el feed. Solo se revela al técnico '
                      'mediante la acción voluntaria del cliente a través del botón explícito "Compartir ubicación exacta" dentro del chat '
                      'privado una vez confirmada la contratación.',
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Sticky Acceptance Action Box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Checkbox 1
                  CheckboxListTile(
                    value: _acceptedTerms,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    checkColor: AppColors.pureBlack,
                    title: const Text(
                      'Acepto las Condiciones del Servicio y la Política de Privacidad.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _acceptedTerms = val ?? false;
                      });
                    },
                  ),

                  // Checkbox 2: ARCO rights consent
                  CheckboxListTile(
                    value: _acceptedArco,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    checkColor: AppColors.pureBlack,
                    title: const Text(
                      'Presto consentimiento expreso al tratamiento de datos (Ley 25.326) y conozco mis derechos ARCO.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _acceptedArco = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_acceptedTerms && _acceptedArco) ? _handleAccept : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: isDark
                            ? const Color(0xFF333333)
                            : const Color(0xFFE5E7EB),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Aceptar y Continuar'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
