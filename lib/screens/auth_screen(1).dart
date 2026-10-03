import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/ui_kit.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await AuthService.instance.signIn(_emailCtrl.text, _passCtrl.text);
      } else {
        await AuthService.instance.signUp(_emailCtrl.text, _passCtrl.text);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, stack) {
      // 🔍 GEÇİCİ: Tam hatayı terminale bas
      debugPrint('❌ EMAIL AUTH ERROR: $e');
      debugPrint('❌ STACK: $stack');

      if (!mounted) return;
      AppSnackBar.error(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      final result = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (result == null) {
        // Kullanıcı iptal etti — sessizce çık
        return;
      }
      Navigator.pop(context, true);
    } catch (e, stack) {
      // 🔍 GEÇİCİ: Tam hatayı terminale bas
      debugPrint('❌ GOOGLE SIGN-IN ERROR: $e');
      debugPrint('❌ STACK: $stack');

      if (!mounted) return;
      AppSnackBar.error(context, AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  bool get _busy => _loading || _googleLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    '🏆',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 56),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isLogin ? 'Giriş Yap' : 'Hesap Oluştur',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Liderlik tablosuna katılmak için giriş yap'
                        : 'Puanlarını kaydet ve sıralamaya gir',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ===== GOOGLE İLE DEVAM ET =====
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _googleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                      ),
                      child: _googleLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black87,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: Color(0xFF4285F4),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Google ile Devam Et',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== AYIRICI =====
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'veya',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ===== E-POSTA =====
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      label: 'E-posta',
                      icon: Icons.email_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'E-posta gerekli';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Geçerli bir e-posta gir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    enabled: !_busy,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      label: 'Şifre',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Şifre gerekli';
                      if (v.length < 6) return 'En az 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.gold,
                            ),
                          )
                        : GradientButton(
                            label: _isLogin ? 'GİRİŞ YAP' : 'KAYIT OL',
                            onTap: _busy ? null : _submit,
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _isLogin = !_isLogin;
                              _formKey.currentState?.reset();
                            }),
                    child: Text(
                      _isLogin
                          ? 'Hesabın yok mu? Kayıt ol'
                          : 'Zaten hesabın var mı? Giriş yap',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.amber, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }
}
