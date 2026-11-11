# Hợp đồng API LibraryFlow

Base URL mặc định `http://127.0.0.1:3000/api`. Thành công trả `{"data": ...}`. Tạo mới dùng HTTP 201. Các thao tác hoàn thành không có dữ liệu trả `{"data":null}`. Lỗi trả `{"error":{"code":"unavailable","message":"Sách hiện không khả dụng."}}`. Màn hình dịch theo `code`.

Gửi `Authorization: Bearer <token>` cho các route yêu cầu phiên. Body JSON dùng `Content-Type: application/json`. Mốc thời gian API theo UTC (ISO 8601), Flutter hiển thị theo giờ của thiết bị.

## Endpoint

| Method và đường dẫn sau `/api` | Quyền | Query, body hoặc dữ liệu |
| --- | --- | --- |
| GET `/health` | Công khai | Trạng thái kết nối MySQL |
| GET `/covers/:filename` | Công khai | Tệp WebP bìa demo |
| POST `/auth/login` | Công khai | `login`, `password` → `token`, `user` |
| GET `/auth/me` | Có phiên | Hồ sơ hiện tại |
| PUT `/auth/change-password` | Có phiên | `current_password`, `new_password` |
| GET `/books` | Có phiên | `q`, `category_id`, `sort=title\|year`, `archived=1` dành cho thủ thư |
| GET `/books/:id` | Có phiên | Độc giả truy cập sách đang hiển thị |
| POST `/books` | Thủ thư | Trường sách → ID |
| PUT `/books/:id` | Thủ thư | Trường sách → ID |
| DELETE `/books/:id` | Thủ thư | Ngừng hiển thị |
| PATCH `/books/:id/restore` | Thủ thư | Hiển thị lại |
| GET `/categories` | Có phiên | Danh sách thể loại |
| POST `/categories` | Thủ thư | `name`, `description` tùy chọn |
| PUT `/categories/:id` | Thủ thư | `name`, `description` tùy chọn |
| DELETE `/categories/:id` | Thủ thư | Xóa thể loại chưa có sách tham chiếu |
| GET `/users` | Thủ thư | `q` lọc độc giả theo tên, mã sinh viên, email, tên đăng nhập |
| GET `/users/:id` | Thủ thư | Hồ sơ độc giả, `active_loans`, `records` |
| PUT `/users/:id` | Chính chủ hoặc thủ thư sửa hồ sơ độc giả | `full_name`, `email` |
| PATCH `/users/:id/status` | Thủ thư | `status: active\|locked` dành cho độc giả |
| POST `/borrow-requests` | Độc giả | `book_id` |
| GET `/borrow-requests` | Có phiên | Độc giả xem yêu cầu của mình, thủ thư xem tất cả |
| PATCH `/borrow-requests/:id/approve` | Thủ thư | Duyệt và tạo phiếu mượn |
| PATCH `/borrow-requests/:id/reject` | Thủ thư | `reason` tùy chọn |
| GET `/borrow-records` | Thủ thư | Tất cả phiếu mượn |
| GET `/borrow-records/my` | Độc giả | Phiếu của người đang đăng nhập |
| PATCH `/borrow-records/:id/return` | Thủ thư | Xác nhận trả sách |
| POST `/renewal-requests` | Độc giả | `borrow_record_id` |
| GET `/renewal-requests` | Có phiên | Độc giả xem yêu cầu của mình, thủ thư xem tất cả |
| PATCH `/renewal-requests/:id/approve` | Thủ thư | Duyệt và tăng hạn trả 7 ngày |
| PATCH `/renewal-requests/:id/reject` | Thủ thư | `reason` tùy chọn |
| GET `/notifications` | Có phiên | `items`, `unread` của người hiện tại |
| PATCH `/notifications/:id/read` | Chính chủ | Đánh dấu đã đọc |
| GET `/statistics/overview` | Thủ thư | `titles`, `copies`, `borrowed`, `readers`, `pending`, `overdue` |
| GET `/statistics/borrow-by-month` | Thủ thư | 12 tháng gần nhất, mỗi dòng `month`, `total` |
| GET `/statistics/books-by-category` | Thủ thư | Số đầu sách hiển thị theo thể loại, mỗi dòng `name`, `total` |
| GET `/statistics/popular-books` | Thủ thư | Tối đa 5 đầu sách, mỗi dòng `id`, `title`, `total` |

Trường bắt buộc khi tạo hoặc sửa sách gồm `book_code`, `title`, `author`, `category_id`, `publisher`, `published_year`, `total_copies`. Có thể thêm `isbn`, `description`, `cover_image`. Máy chủ tính `available_copies`. Ảnh bìa có thể là URL HTTP(S) hoặc đường dẫn bìa demo `/covers/LF001.webp`.

Phiếu mượn có `status` lưu trong MySQL (`active`, `returned`) và `loan_state` tính khi truy vấn (`active`, `due_soon`, `overdue`, `returned`). `overdue_days` làm tròn lên theo khoảng 24 giờ. `renewal_pending` cho biết phiếu có yêu cầu gia hạn đang chờ.

Dashboard đếm đầu sách đang hiển thị, tổng số bản vật lý (bao gồm đầu sách đã ẩn), số bản đang mượn, toàn bộ độc giả (bao gồm bị khóa), hai loại yêu cầu chờ duyệt và phiếu quá hạn. Biểu đồ lượt mượn thống kê theo thời gian duyệt mượn.

## Mã HTTP thường gặp

| Mã | Ý nghĩa |
| --- | --- |
| 400 | Sai định dạng hoặc thiếu trường |
| 401 | Sai mật khẩu hoặc phiên hết hiệu lực |
| 403 | Thiếu quyền hoặc tài khoản bị khóa khi đăng nhập |
| 404 | ID không tồn tại, đối tượng bị ẩn hoặc thuộc độc giả khác |
| 409 | Vi phạm ràng buộc, xung đột tồn kho hoặc nghiệp vụ |
| 413 | Body vượt giới hạn |
| 500 | Lỗi máy chủ |

## Trạng thái và tính nhất quán

| Đối tượng | Giá trị |
| --- | --- |
| Tài khoản | `active`, `locked` |
| Đầu sách | `active`, `archived` |
| Yêu cầu mượn và gia hạn | `pending`, `approved`, `rejected` |
| Phiếu mượn | `active`, `returned` |
| Thông báo | `borrow_approved`, `borrow_rejected`, `renewal_approved`, `renewal_rejected`, `due_soon`, `overdue` |

Tồn kho tuân theo `available_copies = total_copies - số phiếu active của đầu sách`. Khi nhận yêu cầu, API kiểm tra khả dụng và số phiếu hoạt động. Bản sách chỉ được giữ khi yêu cầu được duyệt. Các transaction khóa độc giả trước để tuần tự hóa thao tác cùng độc giả, rồi khóa đầu sách và phiếu liên quan khi cần. Khi xác nhận trả, API từ chối yêu cầu gia hạn đang chờ của phiếu đó trong cùng transaction.
