# LibraryFlow – Ứng dụng quản lý thư viện

Đồ án Lập trình thiết bị di động. Ứng dụng Flutter gọi REST API Express qua Dio. API đọc và ghi dữ liệu bằng MySQL2. Navicat dùng để quản trị MySQL 8.

## 1. Công cụ trên Windows

- Flutter 3.47.9 stable, Dart 3.13.7. Dùng VS Code với extension Flutter/Dart hoặc Android Studio.
- Android Studio, Android SDK, Android Emulator và một máy ảo Android. Android Gradle dùng JDK 17 trở lên. Chạy `flutter doctor -v` và `flutter doctor --android-licenses` để kiểm tra.
- Node.js 22 trở lên, npm và MySQL Community Server 8.0.16 trở lên. Đã kiểm thử API với MySQL 8.4.13.
- Navicat có kết nối đến MySQL. Hướng dẫn cài Flutter và Android ở [tài liệu Flutter cho Windows](https://docs.flutter.dev/platform-integration/android/setup).

## 2. Tạo dữ liệu bằng Navicat

1. Kết nối MySQL Server bằng tài khoản có quyền tạo database và bảng.
2. Mở cửa sổ truy vấn trên kết nối. Mở và chạy toàn bộ [database.sql](database/database.sql). File sẽ tạo và chọn `libraryflow_db`.
3. Mở và chạy [seed.sql](database/seed.sql) đúng một lần trên schema mới. Script dùng mã định danh cố định cho dữ liệu demo.
4. Làm mới kết nối và kiểm tra có 20 đầu sách, 5 thể loại, 5 độc giả và 1 thủ thư.
5. Tạo tài khoản dành riêng cho API nếu cần. Ví dụ sau dùng tài khoản MySQL cục bộ. Thay mật khẩu trước khi chạy.

```sql
CREATE USER 'libraryflow'@'localhost' IDENTIFIED BY 'THAY_BANG_MAT_KHAU_CUA_BAN';
GRANT SELECT, INSERT, UPDATE, DELETE ON libraryflow_db.* TO 'libraryflow'@'localhost';
```

Các hạn trả demo tính từ thời điểm import seed. Khi chạy lại bản demo sau vài ngày, trạng thái sắp đến hạn hoặc quá hạn tự thay đổi theo đồng hồ máy chủ.

## 3. Chạy API

Mở PowerShell ở thư mục `libraryflow`.

```powershell
cd backend
npm ci
Copy-Item .env.example .env
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

Mở `backend/.env`, nhập thông tin MySQL của bạn và đặt kết quả lệnh vừa in vào `JWT_SECRET`.

```dotenv
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=libraryflow
DB_PASSWORD=MAT_KHAU_MYSQL
DB_NAME=libraryflow_db
JWT_SECRET=CHUOI_BI_MAT_DA_TAO
HOST=127.0.0.1
PORT=3000
```

```powershell
npm start
```

Dùng cửa sổ PowerShell khác để kiểm tra MySQL qua API.

```powershell
Invoke-RestMethod http://127.0.0.1:3000/api/health
```

API trả `data.ready = True` khi kết nối database hoạt động. Dùng `npm run dev` để tự khởi động lại API khi sửa source. `CORS_ORIGINS` có thể chứa danh sách origin trình duyệt phân cách bằng dấu phẩy. Flutter Android dùng HTTP native.

## 4. Chạy Flutter trên Android

Từ thư mục gốc, mở một máy ảo trong Device Manager rồi chạy các lệnh sau.

```powershell
cd frontend
flutter pub get
flutter devices
flutter run
```

API mặc định trên Android Emulator là `http://10.0.2.2:3000/api`. `10.0.2.2` là địa chỉ để emulator truy cập máy tính đang chạy backend. Nếu có nhiều thiết bị, dùng `flutter run -d MA_THIET_BI`.

Với điện thoại Android thật, bật USB debugging, kết nối cùng mạng Wi-Fi, rồi dùng `ipconfig` để lấy IPv4 máy tính. Đặt `HOST=0.0.0.0` trong `backend/.env`, khởi động lại API và cho phép cổng TCP 3000 trên mạng riêng trong Windows Firewall. Kiểm tra `http://IP_MAY_TINH:3000/api/health` từ trình duyệt điện thoại. Chạy ứng dụng với IP thực tế.

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000/api
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.25:3000/api
```

APK debug ở `frontend/build/app/outputs/flutter-apk/app-debug.apk`. Cấu hình Android chỉ bật HTTP cleartext trong bản debug để demo local. Khi dùng bản release, cấu hình API và ảnh bìa bên ngoài với HTTPS.

## 5. Tài khoản demo

| Vai trò | Tên đăng nhập | Email | Mật khẩu |
| --- | --- | --- | --- |
| Thủ thư | `thuthu` | `thuthu@libraryflow.test` | `Demo@123456` |
| Độc giả | `sv01` | `sv01@libraryflow.test` | `Demo@123456` |
| Độc giả | `sv02` | `sv02@libraryflow.test` | `Demo@123456` |
| Độc giả | `sv03` | `sv03@libraryflow.test` | `Demo@123456` |
| Độc giả | `sv04` | `sv04@libraryflow.test` | `Demo@123456` |
| Độc giả bị khóa | `sv05` | `sv05@libraryflow.test` | `Demo@123456` |

Dữ liệu và tài khoản ở bảng này chỉ dùng cho môi trường phát triển. MySQL lưu bcrypt hash. Flutter lưu JWT bằng `flutter_secure_storage`. JWT hết hạn sau 12 giờ. Đổi mật khẩu và khóa tài khoản vô hiệu hóa token đã cấp.

## 6. Kịch bản demo trên thiết bị

1. Đăng nhập `sv01`. Tìm **Dế Mèn phiêu lưu ký** và mở chi tiết sách. Trong **Mượn trả → Yêu cầu mượn của tôi**, xác nhận yêu cầu mẫu ở trạng thái chờ duyệt. Gửi thêm yêu cầu cho **Hai đứa trẻ** để có hai phiếu chờ trước khi thủ thư duyệt.
2. Đăng nhập `thuthu`, mở **Mượn trả → Yêu cầu mượn**, duyệt phiếu Dế Mèn của SV001. Kiểm tra số bản khả dụng giảm 1. Thử duyệt thêm cho cùng độc giả khi họ đang mượn 3 cuốn để kiểm tra quy tắc giới hạn.
3. Đăng nhập lại `sv01`. Mở thông báo, đánh dấu đã đọc và kiểm tra huy hiệu. Kiểm tra phiếu mới trong **Sách đang mượn**, với hạn trả sau 14 ngày.
4. Trong phiên thủ thư, duyệt yêu cầu gia hạn mẫu của **Phát triển ứng dụng Flutter**. Kiểm tra hạn trả tăng 7 ngày. Xác nhận trả một phiếu rồi kiểm tra tồn kho và lịch sử.
5. Mở **Sách quá hạn** để xem phiếu mẫu của SV002. Mở **Thống kê** để xem số liệu và biểu đồ từ API.
6. Trong **Tài khoản → Cài đặt**, chuyển sang tiếng Anh và giao diện tối. Mở lại app để kiểm tra lưu tùy chọn. Khi cài mới, app dùng tiếng Việt và giao diện sáng.

## 7. Kiểm thử

```powershell
# Trong backend
npm test

# Kiểm thử tích hợp với tài khoản MySQL có quyền CREATE và DROP database kiểm thử.
# Có thể đặt DB_USER, DB_PASSWORD và DB_PORT trong PowerShell để dùng tài khoản riêng.
$env:LIBRARYFLOW_INTEGRATION = "1"
npm test
Remove-Item Env:LIBRARYFLOW_INTEGRATION
```

Test tích hợp tạo database tên ngẫu nhiên, import hai script SQL rồi dọn database đó khi kết thúc. Nên dùng một MySQL instance phát triển cho test này.

```powershell
# Trong frontend
flutter analyze
flutter test
```

Test Flutter bao gồm khôi phục phiên, đăng nhập, gửi yêu cầu từ giao diện, chuyển ngôn ngữ/chủ đề, màn hình thủ thư và khôi phục kết nối. Khi API đang chạy với seed chưa thay đổi tài khoản demo, chạy thêm test kết nối Dio → Express → MySQL từ máy tính.

```powershell
flutter test --dart-define=LIVE_API_URL=http://127.0.0.1:3000/api test/live_api_test.dart
```

Kịch bản ở mục 6 kiểm tra giao diện và kết nối trên Android thật hoặc emulator.

## 8. Thông tin nhóm và cấu trúc

Điền `frontend/assets/team.json`. Mỗi mục trong `members` dùng dạng dưới đây. Điền đường dẫn repository GitHub vào `github` khi nhóm có repository.

```json
{
  "github": "https://github.com/ten-nhom/libraryflow",
  "members": [
    {
      "name": "Họ tên thành viên",
      "student_code": "Mã sinh viên",
      "role_vi": "Phát triển Flutter",
      "role_en": "Flutter development"
    }
  ]
}
```

| Vị trí | Nội dung |
| --- | --- |
| `frontend/lib/app`, `core` | Provider quản lý phiên, cấu hình Dio, xử lý lỗi |
| `frontend/lib/screens`, `widgets`, `l10n` | Màn hình, thành phần dùng chung, chuỗi tiếng Việt/Anh |
| `backend/src` | HTTP, xác thực, danh mục, lưu thông, thống kê và thông báo |
| `backend/public/covers` | Ảnh bìa minh họa cho dữ liệu demo |
| `database` | Schema MySQL và dữ liệu demo |
| [docs/api.md](docs/api.md) | Endpoint, hợp đồng JSON và quy tắc dữ liệu |
| [docs/phan-tich-thiet-ke.md](docs/phan-tich-thiet-ke.md) | Nội dung SRS/SAD và dữ liệu để tự vẽ UML |

## 9. Git

Dùng `git log --oneline --reverse` để xem lịch sử từ template Flutter. Để commit với danh tính nhóm trên Windows, cấu hình trong thư mục dự án.

```powershell
git config user.name "Họ tên của bạn"
git config user.email "email@example.com"
```
