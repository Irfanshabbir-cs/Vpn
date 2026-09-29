import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

class RemoteAuthRepository implements AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  RemoteAuthRepository({Dio? dio, FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: AppConstants.baseApiUrl, connectTimeout: AppConstants.connectTimeout)),
        _storage = storage;

  @override
  Future<UserModel> login({required String email, required String password}) =>
      _authenticate('/auth/login', {'email': email, 'password': password});

  @override
  Future<UserModel> register({required String email, required String password}) =>
      _authenticate('/auth/register', {'email': email, 'password': password});

  Future<UserModel> _authenticate(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      final data = response.data!;
      await _saveTokens(data);
      return UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    } on DioException catch (error) {
      throw AuthException(_errorMessage(error));
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];
    if (accessToken is String && refreshToken is String) {
      await _storage.write(key: AppConstants.keyAccessToken, value: accessToken);
      await _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
    }
  }

  @override
  Future<UserModel?> currentUser() async {
    final accessToken = await _storage.read(key: AppConstants.keyAccessToken);
    if (accessToken == null) return null;
    try {
      final response = await _getCurrentUser(accessToken);
      return UserModel.fromJson(Map<String, dynamic>.from(response.data!));
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) return null;
      final refreshToken = await _storage.read(key: AppConstants.keyRefreshToken);
      if (refreshToken == null) {
        await _clearTokens();
        return null;
      }
      try {
        final refreshed = await _dio.post<Map<String, dynamic>>('/auth/refresh', data: {'refresh_token': refreshToken});
        await _saveTokens(refreshed.data!);
        final retry = await _getCurrentUser(refreshed.data!['access_token'] as String);
        return UserModel.fromJson(Map<String, dynamic>.from(retry.data!));
      } on DioException {
        await _clearTokens();
        return null;
      }
    }
  }

  Future<Response<Map<String, dynamic>>> _getCurrentUser(String token) => _dio.get<Map<String, dynamic>>(
        '/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _dio.post<void>('/auth/password/forgot', data: {'email': email});
    } on DioException catch (error) {
      throw AuthException(_errorMessage(error));
    }
  }

  @override
  Future<void> verifyOtp({required String email, required String otp}) async {
    try {
      await _dio.post<void>('/auth/otp/verify', data: {'email': email, 'otp': otp});
    } on DioException catch (error) {
      throw AuthException(_errorMessage(error));
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _storage.read(key: AppConstants.keyRefreshToken);
    try {
      if (refreshToken != null) await _dio.post<void>('/auth/logout', data: {'refresh_token': refreshToken});
    } on DioException {
      // Always remove local credentials, even when the API is unavailable.
    } finally {
      await _clearTokens();
    }
  }

  @override
  Future<UserModel> signInWithGoogle() => Future.error(AuthException('Google sign-in is not configured on the backend.'));

  @override
  Future<UserModel> signInWithApple() => Future.error(AuthException('Apple sign-in is not configured on the backend.'));

  Future<void> _clearTokens() async {
    await _storage.delete(key: AppConstants.keyAccessToken);
    await _storage.delete(key: AppConstants.keyRefreshToken);
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map && (data['error'] as Map)['message'] is String) {
      return (data['error'] as Map)['message'] as String;
    }
    return 'Could not reach the ShieldVPN API. Check that the backend is running.';
  }
}