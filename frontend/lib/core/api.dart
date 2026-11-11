import 'package:dio/dio.dart';

typedef Json = Map<String, dynamic>;

class ApiFailure implements Exception {
  const ApiFailure(this.code, {this.status});
  final String code;
  final int? status;
}

class Api {
  Api({Dio? client})
    : _dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://10.0.2.2:3000/api',
              ),
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
            ),
          );

  final Dio _dio;

  String coverUrl(String value) => value.startsWith('/covers/')
      ? '${_dio.options.baseUrl.replaceFirst(RegExp(r"/+$"), "")}$value'
      : value;

  String? token;
  void Function(String)? onUnauthorized;

  Future<dynamic> send(
    String path, {
    String method = 'GET',
    Json? body,
    Json? query,
  }) async {
    final sentToken = token;
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            if (sentToken != null) 'Authorization': 'Bearer $sentToken',
          },
        ),
      );
      return (response.data as Json)['data'];
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 && sentToken != null && path != '/auth/login') {
        onUnauthorized?.call(sentToken);
      }
      final payload = error.response?.data;
      final details = payload is Map ? payload['error'] : null;
      final code = details is Map ? details['code'] : null;
      throw ApiFailure(
        code is String ? code : (status == null ? 'offline' : 'server_error'),
        status: status,
      );
    }
  }

  Future<Json> object(String path, {Json? query}) async =>
      await send(path, query: query) as Json;

  Future<List<Json>> list(String path, {Json? query}) async =>
      rows(await send(path, query: query));
}

List<Json> rows(dynamic value) => (value as List).cast<Json>();
int countOf(dynamic value) => int.tryParse('$value') ?? 0;
