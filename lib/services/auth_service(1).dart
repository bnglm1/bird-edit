import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  // ============================================================
  // ⚠️ BURAYI DOLDURMAN GEREKİYOR
  //
  // `android/app/google-services.json` dosyandan alınır:
  //   1. Dosyayı aç
  //   2. "oauth_client" listesini bul
  //   3. İçinde "client_type": 3 olan bloktaki
  //      "client_id" değerini kopyala
  //   4. Aşağıya yapıştır
  //
  // Örnek format:
  //   '7690250755006392-abc123.apps.googleusercontent.com'
  // ============================================================
  static const String _kWebClientId =
      '517948997064-01l24afnbfvkni93mps356m61g5pem9s.apps.googleusercontent.com';

  final GoogleSignIn _google = GoogleSignIn(
    serverClientId: _kWebClientId.isEmpty ? null : _kWebClientId,
  );

  User? get user => _auth.currentUser;
  String? get uid => user?.uid;
  String? get email => user?.email;
  bool get isSignedIn => user != null;

  List<String> get providerIds =>
      user?.providerData.map((p) => p.providerId).toList() ?? const [];

  bool get isGoogleUser => providerIds.contains('google.com');
  bool get isEmailUser => providerIds.contains('password');

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== E-POSTA ====================

  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ==================== GOOGLE ====================

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _google.signOut();
    } catch (_) {
      // İlk girişte oturum yoktu, sorun değil
    }

    final googleUser = await _google.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  // ==================== ÇIKIŞ ====================

  Future<void> signOut() async {
    try {
      if (isGoogleUser) {
        await _google.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('signOut error: $e');
    }
  }

  // ==================== HATA MESAJLARI ====================

  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Bu e-posta zaten kayıtlı.';
        case 'invalid-email':
          return 'Geçersiz e-posta adresi.';
        case 'weak-password':
          return 'Şifre en az 6 karakter olmalı.';
        case 'user-not-found':
          return 'Bu e-posta ile kayıt bulunamadı.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-posta veya şifre hatalı.';
        case 'network-request-failed':
          return 'İnternet bağlantısı yok.';
        case 'account-exists-with-different-credential':
          return 'Bu e-posta başka bir giriş yöntemiyle kayıtlı.';
        case 'operation-not-allowed':
          return 'Bu giriş yöntemi etkin değil.';
        default:
          if (kDebugMode) debugPrint('Auth error: ${e.code} ${e.message}');
          return 'Bir hata oluştu: ${e.code}';
      }
    }

    final s = e.toString();
    if (s.contains('sign_in_canceled') || s.contains('Canceled')) {
      return 'Giriş iptal edildi.';
    }
    if (s.contains('network_error')) {
      return 'İnternet bağlantısı yok.';
    }

    if (kDebugMode) debugPrint('Auth error: $e');
    return 'Beklenmeyen bir hata oluştu.';
  }
}
