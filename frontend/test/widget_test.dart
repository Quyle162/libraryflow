import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libraryflow/app/session.dart';
import 'package:libraryflow/core/api.dart';
import 'package:libraryflow/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoApi extends Api {
  DemoApi({this.role = 'reader'});
  final String role;
  final borrowRequests = <Json>[];
  bool unavailable = false;

  Json get profile => {'id': 2, 'role': role, 'full_name': 'Nguyễn Hoàng Nam'};

  final book = <String, dynamic>{
    'id': 1,
    'title': 'Nhập môn Dart',
    'author': 'Nguyễn Minh Tâm',
    'category_id': 1,
    'category_name': 'Công nghệ',
    'status': 'active',
    'available_copies': 3,
    'total_copies': 4,
  };

  @override
  Future<dynamic> send(
    String path, {
    String method = 'GET',
    Json? body,
    Json? query,
  }) async {
    if (unavailable) throw const ApiFailure('offline');
    switch (path) {
      case '/auth/login':
        return {'token': 'demo-token', 'user': profile};
      case '/auth/me':
        return profile;
      case '/categories':
        return [
          {'id': 1, 'name': 'Công nghệ'},
        ];
      case '/books':
        return [book];
      case '/books/1':
        return book;
      case '/notifications':
        return {'items': <Json>[], 'unread': 1};
      case '/borrow-requests':
        if (method == 'POST') borrowRequests.add(body!);
        return {'id': 1};
      case '/statistics/overview':
        return {
          'titles': 20,
          'copies': 80,
          'borrowed': 3,
          'readers': 5,
          'pending': 3,
          'overdue': 1,
        };
      case '/statistics/borrow-by-month':
        return [
          {'month': '2026-10', 'total': 1},
          {'month': '2026-11', 'total': 2},
        ];
      case '/statistics/books-by-category':
        return [
          {'name': 'Công nghệ', 'total': 4},
        ];
      case '/statistics/popular-books':
        return [
          {'id': 1, 'title': 'Nhập môn Dart', 'total': 3},
        ];
      default:
        throw StateError('Unexpected request: $method $path');
    }
  }
}

Future<Session> mount(
  WidgetTester tester,
  DemoApi api, {
  bool stored = false,
}) async {
  FlutterSecureStorage.setMockInitialValues(
    stored ? {'libraryflow.token': 'demo-token'} : {},
  );
  SharedPreferences.setMockInitialValues({});
  final session = Session(api, await SharedPreferences.getInstance());
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: session, child: const LibraryFlow()),
  );
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  await session.restore();
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('Đăng nhập mặc định tiếng Việt và gửi yêu cầu mượn', (
    tester,
  ) async {
    final api = DemoApi();
    final session = await mount(tester, api);
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập thông tin.'), findsWidgets);
    await tester.enterText(find.byType(TextFormField).at(0), 'sv01');
    await tester.enterText(find.byType(TextFormField).at(1), 'Demo@123456');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(session.librarian, isFalse);
    expect(find.text('Quản lý độc giả'), findsNothing);
    await tester.tap(find.text('Sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập môn Dart'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Yêu cầu mượn'), 180);
    await tester.tap(find.text('Yêu cầu mượn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.borrowRequests, [
      {'book_id': 1},
    ]);
  });

  testWidgets('Đổi ngôn ngữ và giao diện trong Cài đặt', (tester) async {
    final session = await mount(tester, DemoApi(), stored: true);
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếng Anh').last);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(session.preferences.getString('language'), 'en');
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(session.theme, ThemeMode.dark);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(session.user, isNull);
  });

  testWidgets('Khôi phục phiên và hiển thị dashboard thủ thư', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, DemoApi(role: 'librarian'), stored: true);
    expect(find.text('Nguyễn Hoàng Nam'), findsOneWidget);
    expect(find.text('Quản lý thể loại'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Thống kê'),
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Thống kê'));
    await tester.pumpAndSettle();
    expect(find.text('Lượt mượn theo tháng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hiển thị lỗi kết nối và khôi phục phiên khi thử lại', (
    tester,
  ) async {
    final api = DemoApi()..unavailable = true;
    await mount(tester, api, stored: true);
    expect(
      find.text('Không thể kết nối máy chủ. Kiểm tra mạng và địa chỉ API.'),
      findsOneWidget,
    );
    api.unavailable = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Hoàng Nam'), findsOneWidget);
  });
}
