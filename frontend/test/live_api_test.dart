import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libraryflow/core/api.dart';

const liveApiUrl = String.fromEnvironment('LIVE_API_URL');

void main() {
  test(
    'Dio gọi Express và đọc dữ liệu demo từ MySQL',
    () async {
      final dio = Dio(BaseOptions(baseUrl: liveApiUrl));
      addTearDown(dio.close);
      final api = Api(client: dio);

      expect(await api.object('/health'), {'ready': true});
      final login = await api.send(
        '/auth/login',
        method: 'POST',
        body: {'login': 'sv01', 'password': 'Demo@123456'},
      ) as Json;
      api.token = login['token'] as String;

      expect((await api.object('/auth/me'))['role'], 'reader');
      final books = await api.list('/books', query: {'q': 'Dart'});
      expect(books.single['book_code'], 'LF001');
      expect(
        api.coverUrl(books.single['cover_image'] as String),
        '$liveApiUrl/covers/LF001.webp',
      );

      final records = await api.list('/borrow-records/my');
      expect(records.any((row) => row['status'] == 'active'), isTrue);
      expect(DateTime.parse(records.first['due_at'] as String).isUtc, isTrue);

      await expectLater(
        api.object('/statistics/overview'),
        throwsA(
          isA<ApiFailure>().having((error) => error.status, 'status', 403),
        ),
      );
    },
    skip: liveApiUrl.isEmpty
        ? 'Chỉ định LIVE_API_URL để kiểm thử với API demo.'
        : false,
  );
}
