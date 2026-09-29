import 'dart:async';
import 'dart:math';
import '../models/user_model.dart';

/// Abstract contract. Swap [MockAuthRepository] for a real Dio + Firebase
/// implementation once the backend from docs/BACKEND_GUIDE.md is live.
abstract class AuthRepository {
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> register({required String email, required String password});
  Future<UserModel> signInWithGoogle();
  Future<UserModel> signInWithApple();
  Future<void> sendPasswordReset(String email);
  Future<void> verifyOtp({required String email, required String otp});
  Future<void> logout();
  Future<UserModel?> currentUser();
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// In-memory mock so every screen is demoable with zero backend.
/// Replace with `RemoteAuthRepository` (Dio + JWT refresh interceptor)
/// once BASE_API_URL points at a real server.
class MockAuthRepository implements AuthRepository {
  UserModel? _user;

  @override
  Future<UserModel> login({required String email, required String password}) async {
    await _simulateLatency();
    if (password.length < 6) {
      throw AuthException('Incorrect email or password.');
    }
    _user = UserModel(id: 'usr_${email.hashCode}', email: email, emailVerified: true);
    return _user!;
  }

  @override
  Future<UserModel> register({required String email, required String password}) async {
    await _simulateLatency();
    _user = UserModel(id: 'usr_${email.hashCode}', email: email, emailVerified: false);
    return _user!;
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    await _simulateLatency();
    _user = const UserModel(
      id: 'usr_google',
      email: 'google.user@example.com',
      displayName: 'Google User',
      emailVerified: true,
    );
    return _user!;
  }

  @override
  Future<UserModel> signInWithApple() async {
    await _simulateLatency();
    _user = const UserModel(
      id: 'usr_apple',
      email: 'apple.user@example.com',
      displayName: 'Apple User',
      emailVerified: true,
    );
    return _user!;
  }

  @override
  Future<void> sendPasswordReset(String email) async => _simulateLatency();

  @override
  Future<void> verifyOtp({required String email, required String otp}) async {
    await _simulateLatency();
    if (otp != '123456' && Random().nextBool()) {
      // Deterministic happy-path code for demo purposes: 123456 always works.
      throw AuthException('Invalid verification code.');
    }
  }

  @override
  Future<void> logout() async {
    await _simulateLatency();
    _user = null;
  }

  @override
  Future<UserModel?> currentUser() async => _user;

  Future<void> _simulateLatency() => Future.delayed(const Duration(milliseconds: 600));
}
