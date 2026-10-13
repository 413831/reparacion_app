import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'tech-reviewer@reparatutti.com');
  final _passwordController = TextEditingController(text: 'Reviewer2026!');
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillReviewerCredentials(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
    });
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa correo y contraseña')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = ref.read(secureStorageServiceProvider);
      final isTech = email.contains('tech');

      // Persist mock authenticated session in secure hardware storage
      await storage.saveAuthToken('jwt_session_${DateTime.now().millisecondsSinceEpoch}');
      await storage.saveUserId(isTech ? '77777777-7777-7777-7777-777777777777' : '88888888-8888-8888-8888-888888888888');
      await storage.saveUserRole(isTech ? 'technician' : 'client');
      await storage.saveUserData({
        'email': email,
        'full_name': isTech ? 'Técnico Evaluador App Store' : 'Cliente Evaluador App Store',
        'role': isTech ? 'technician' : 'client',
        'kyc_status': 'verified',
      });

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // App Brand
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.handyman_rounded, size: 40, color: AppColors.pureBlack),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Reparatutti',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.pureBlack,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Servicios de reparación y mantenimiento para el hogar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // Store Reviewer Quick-Fill Box (Mandatory for frictionless App Store Review)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.rate_review_rounded, size: 18, color: AppColors.mustardLight),
                        SizedBox(width: 8),
                        Text(
                          'App Store / Play Reviewers',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Credenciales pre-aprobadas sin fricción de KYC:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.engineering_rounded, size: 16),
                          label: const Text('Técnico Evaluador (KYC OK)', style: TextStyle(fontSize: 11.5)),
                          onPressed: () => _fillReviewerCredentials(
                            'tech-reviewer@reparatutti.com',
                            'Reviewer2026!',
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.person_rounded, size: 16),
                          label: const Text('Cliente Evaluador', style: TextStyle(fontSize: 11.5)),
                          onPressed: () => _fillReviewerCredentials(
                            'client-reviewer@reparatutti.com',
                            'Reviewer2026!',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                    foregroundColor: AppColors.pureBlack,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pureBlack),
                        )
                      : const Text('Iniciar Sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),

              // Terms Link
              Center(
                child: TextButton(
                  onPressed: () => context.push('/terms'),
                  child: const Text('Términos y Condiciones (Ley 25.326)', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
