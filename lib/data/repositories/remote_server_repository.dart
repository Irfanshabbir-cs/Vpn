import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../models/server_model.dart';

class RemoteServerRepository {
  final Dio _dio;

  RemoteServerRepository({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: AppConstants.baseApiUrl, connectTimeout: AppConstants.connectTimeout));

  Future<List<ServerModel>> fetchServers({String? country, String? category, String? sort}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/servers',
      queryParameters: {
        if (country != null) 'country': country,
        if (category != null) 'category': category,
        if (sort != null) 'sort': sort,
        'page': 1,
        'page_size': 100,
      },
    );
    final rows = response.data!['data'] as List<dynamic>;
    return rows.map((row) => ServerModel.fromJson(Map<String, dynamic>.from(row as Map))).toList();
  }
}