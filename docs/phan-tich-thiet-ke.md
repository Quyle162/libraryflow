# Phân tích và thiết kế LibraryFlow

## SRS

### Mục tiêu và phạm vi

LibraryFlow số hóa danh mục sách, yêu cầu mượn, xác nhận trả, gia hạn và theo dõi hạn trả tại thư viện trường. Độc giả gửi yêu cầu qua điện thoại. Thủ thư quyết định và xác nhận việc nhận hoặc trả sách tại quầy. Hệ thống theo dõi số bản theo đầu sách, chưa quản lý mã vạch từng bản vật lý. Đồ án tập trung vào mượn trả, thông báo trong app và thống kê.

### Actor

| Actor | Mục tiêu |
| --- | --- |
| Độc giả | Tìm sách, gửi và theo dõi yêu cầu, quản lý hồ sơ và thông báo |
| Thủ thư | Quản lý danh mục và độc giả, xử lý yêu cầu, theo dõi tồn kho và quá hạn |
| Bộ hẹn giờ backend | Tạo thông báo đến hạn và quá hạn khi API đang chạy |

### Yêu cầu chức năng và danh sách use case

| Mã | Use case | Actor | Kết quả |
| --- | --- | --- | --- |
| UC01 | Đăng nhập, khôi phục phiên, đăng xuất | Cả hai | Màn hình đúng vai trò và token được lưu hoặc xóa |
| UC02 | Xem, sửa hồ sơ và đổi mật khẩu | Cả hai | Hồ sơ mới được lưu, token cũ hết hiệu lực sau đổi mật khẩu |
| UC03 | Tìm, lọc, sắp xếp và xem sách | Cả hai | Danh mục đúng theo từ khóa, thể loại và quyền |
| UC04 | Thêm, sửa, ẩn, hiển thị lại sách | Thủ thư | Thông tin và số bản khả dụng nhất quán |
| UC05 | Quản lý thể loại | Thủ thư | Thể loại được thêm/sửa hoặc xóa khi chưa có tham chiếu |
| UC06 | Xem, tìm, khóa/mở khóa độc giả | Thủ thư | Xem hồ sơ và lịch sử, khóa tài khoản vô hiệu hóa phiên |
| UC07 | Gửi và theo dõi yêu cầu mượn | Độc giả | Yêu cầu chờ duyệt |
| UC08 | Duyệt hoặc từ chối mượn | Thủ thư | Yêu cầu đã xử lý và thông báo được lưu |
| UC09 | Xem sách đang mượn, lịch sử và quá hạn | Cả hai | Hiển thị phiếu theo quyền và trạng thái |
| UC10 | Xác nhận trả sách | Thủ thư | Phiếu đã trả, ghi ngày trả và hoàn tồn kho |
| UC11 | Gửi và theo dõi yêu cầu gia hạn | Độc giả | Yêu cầu chờ duyệt |
| UC12 | Duyệt hoặc từ chối gia hạn | Thủ thư | Cập nhật hạn trả khi duyệt và lưu thông báo |
| UC13 | Xem và đánh dấu thông báo | Cả hai | Thông báo được đọc và cập nhật huy hiệu |
| UC14 | Tạo nhắc sắp đến hạn, quá hạn | Bộ hẹn giờ backend | Một thông báo trên mỗi mốc cho từng hạn trả |
| UC15 | Xem dashboard và thống kê | Thủ thư | Số liệu và biểu đồ lấy từ MySQL |
| UC16 | Cài đặt ngôn ngữ, chủ đề và xem thông tin nhóm | Cả hai | Tùy chọn được lưu trên thiết bị |

### Yêu cầu phi chức năng

- **Bảo mật.** API xác minh chữ ký, hạn và phiên bản token, đọc quyền và trạng thái tài khoản từ MySQL. Hash mật khẩu bằng bcrypt. Dùng tham số truy vấn, kiểm tra quyền sở hữu phiếu và thông báo, giới hạn kích thước JSON.
- **Tính toàn vẹn.** MySQL dùng InnoDB, khóa ngoại, chỉ mục unique, CHECK và transaction. Tổng số bản luôn lớn hơn hoặc bằng số bản đang được mượn.
- **Khả dụng.** Giao diện phản hồi khi API đang tải, danh sách trống hoặc mất kết nối. Xác nhận trước khi ẩn/xóa hoặc xử lý phiếu.
- **Bản địa hóa.** Tiếng Việt mặc định. Tiếng Anh do người dùng chọn. Chuỗi giao diện và mã lỗi có hai bản dịch. Tên sách, thể loại, tên người dùng và lý do do thủ thư nhập giữ nguyên dữ liệu gốc.
- **Hiệu năng.** Pool tái sử dụng tối đa 10 kết nối. Chỉ mục hỗ trợ trạng thái, hạn trả và tổng hợp theo tháng. Phạm vi thiết kế là một thư viện trường với danh mục dùng trong đồ án.
- **Triển khai.** Flutter Android, API Node.js cục bộ và MySQL 8 có thể quản trị bằng Navicat.

### Luồng chính, thay thế và ngoại lệ

| Use case | Điều kiện trước | Luồng chính | Thay thế hoặc ngoại lệ |
| --- | --- | --- | --- |
| UC01 | Đã có tài khoản | Nhập email hoặc tên đăng nhập và mật khẩu → API xác thực → lưu JWT → mở điều hướng đúng vai trò | Sai thông tin trả 401. Tài khoản khóa trả 403. Khi mở lại app, mất mạng cho phép thử lại và JWT hết hạn đưa về đăng nhập |
| UC04 | Thủ thư có phiên | Nhập thông tin → API xác thực trường và khóa dòng khi cập nhật → tính lại khả dụng → làm mới danh mục | Mã/ISBN trùng, thể loại đã xóa, hoặc tổng thấp hơn số đang mượn trả 409. Ẩn sách giữ các liên kết lịch sử |
| UC07 | Độc giả hoạt động | Chọn sách → gửi `book_id` → khóa người dùng và sách → kiểm tra điều kiện → ghi yêu cầu | Hết tồn, đã đủ 3 lượt đang mượn, yêu cầu trùng hoặc đang mượn đầu sách trả 409 |
| UC08 | Yêu cầu đang chờ | Mở chi tiết → duyệt → khóa hàng liên quan và kiểm tra lại điều kiện → tạo phiếu, giảm tồn, ghi hạn 14 ngày và thông báo → commit | Từ chối có lý do tùy chọn và lưu thông báo. Xung đột, hết tồn hoặc yêu cầu đã xử lý trả 409, các thay đổi trong giao dịch được rollback |
| UC10 | Phiếu đang mượn, sách đã trả tại quầy | Thủ thư xác nhận → cập nhật trạng thái và ngày trả → tăng tồn → ghi nhật ký | Phiếu đã trả trả 409. Yêu cầu gia hạn đang chờ tự chuyển từ chối trong cùng transaction |
| UC11/12 | Phiếu thuộc độc giả, còn hạn, chưa gia hạn | Độc giả gửi yêu cầu → thủ thư duyệt → API kiểm tra lại điều kiện → cộng 7 ngày vào hạn hiện tại, tăng bộ đếm, thông báo | Từ chối giữ hạn cũ. Phiếu đã trả, quá hạn, đã gia hạn hoặc có yêu cầu chờ trả lỗi. Phiếu thuộc người khác trả 404 |
| UC13/14 | Phiếu còn hoạt động hoặc có sự kiện duyệt | Sự kiện tạo thông báo. Bộ hẹn giờ và API danh sách tạo nhắc còn tối đa 3 ngày hoặc đã quá hạn. Độc giả đánh dấu đã đọc | Unique `event_key` loại trùng mốc. Đọc ID thông báo của người khác trả 404 |
| UC16 | Đã đăng nhập | Vào Cài đặt → đổi ngôn ngữ hoặc chủ đề → lưu SharedPreferences và dựng lại UI | Cài mới dùng tiếng Việt và giao diện sáng |

## SAD

### Thành phần

| Lớp hoặc module | Trách nhiệm | Phụ thuộc |
| --- | --- | --- |
| `LibraryFlow`, `LibraryShell` | Theme, locale, màn hình theo phiên và điều hướng | `Session`, Navigator, Material 3 |
| `Session` | Khôi phục JWT, đăng nhập, đăng xuất, hồ sơ, huy hiệu, tùy chọn | `Api`, Secure Storage, SharedPreferences |
| `Api`, `ApiFailure` | HTTP, header JWT, giải mã JSON và ánh xạ lỗi | Dio, REST API |
| `Strings` | Cung cấp chuỗi theo locale của context | flutter_localizations, bảng chuỗi VI/EN |
| `DataPanel<T>`, `Collection` | Trạng thái tải/lỗi/trống và hiển thị dữ liệu | FutureBuilder, ListView |
| `PageFrame`, `EditFields`, `ActionButton`, `StatusTag` | Khung trang, form tái sử dụng, xác nhận và trình bày trạng thái | Material 3, Strings |
| `BooksPage`, `BookDetails`, `BookForm` | Danh mục, lọc, chi tiết và sửa dữ liệu | Api, Session, DataPanel, EditFields |
| `CirculationPage`, `CirculationDetails` | Danh sách và thao tác mượn, trả, gia hạn | Api, Session, CirculationView |
| `CategoriesPage`, `ReadersPage`, `ReaderDetails` | Quản lý thể loại và độc giả | Api, EditFields, DataPanel |
| `HomePage`, `StatisticsPanel`, `MonthlyChart`, `CategoryChart` | Dashboard và báo cáo theo vai trò | Api, fl_chart |
| `createApp`, `authRoutes`, `catalogRoutes` | Cài middleware HTTP, xác thực, phân quyền và CRUD | Express, JWT, bcryptjs, MySQL2 |
| `circulationRoutes`, `reportingRoutes` | Xử lý nghiệp vụ, thống kê và nhắc hạn | pool, transaction, MySQL |
| `ApiError`, `errors` | Chuẩn hóa mã và nội dung lỗi | Express |

Các màn hình dùng đối tượng JSON đã giải mã cho bản ghi đơn giản. Kiểu `Json` là alias của `Map<String, dynamic>`. Những kiểu widget, trạng thái và phương thức nêu trên lấy từ source để nhóm đối chiếu khi tự dựng class diagram.

### Mô hình dữ liệu và bội số

| Quan hệ | Bội số và mục đích |
| --- | --- |
| Category → Book | Một thể loại chứa nhiều đầu sách. Mỗi đầu sách thuộc một thể loại |
| User → BorrowRequest, BorrowRecord, RenewalRequest, Notification, ActivityLog | Một người dùng có nhiều bản ghi theo từng nghiệp vụ |
| Book → BorrowRequest, BorrowRecord | Một đầu sách có nhiều yêu cầu và phiếu qua thời gian |
| BorrowRequest → BorrowRecord | Một yêu cầu có tối đa một phiếu. FK ghép giữ đúng người và đầu sách |
| BorrowRecord → RenewalRequest | Một phiếu có nhiều yêu cầu theo thời gian, tối đa một yêu cầu đang chờ và một lần được gia hạn |
| User → reviewed_by | Thủ thư có thể xử lý nhiều yêu cầu |
| Notification → event_key | Khóa duy nhất cho mỗi mốc nhắc hạn của một phiếu |

Các cột sinh `pending_book`, `active_book` và `pending_record` giữ ràng buộc unique có điều kiện. `token_version` vô hiệu hóa JWT cũ khi khóa tài khoản hoặc đổi mật khẩu. `kind` và `book_title` giúp Flutter dịch nhãn thông báo. `rejection_reason` lưu lý do xem lại. `activity_logs` ghi người xử lý, thao tác và mã bản ghi.

### Trình tự để tự vẽ sequence diagram

1. **Đăng nhập.** LoginPage → Session.signIn → Api.send → Express authRoutes → MySQL đọc users → bcrypt so hash → JWT ký → Flutter lưu token → LibraryShell. Nhánh sai thông tin dừng ở API. Khôi phục phiên dùng GET /auth/me.
2. **Duyệt mượn.** CirculationDetails → PATCH approve → middleware xác thực và thủ thư → transaction → khóa người dùng, sách, yêu cầu → kiểm tra tồn và giới hạn → tạo phiếu, cập nhật tồn và yêu cầu, thêm thông báo và nhật ký → commit → màn hình danh sách tải lại.
3. **Trả sách.** CirculationDetails → PATCH return → kiểm tra thủ thư → khóa người dùng, sách, phiếu → cập nhật phiếu và tồn kho → xử lý gia hạn đang chờ nếu có → commit → danh sách tải lại.
4. **Gia hạn.** CirculationDetails → POST renewal-requests → kiểm tra phiếu chính chủ và điều kiện → ghi yêu cầu. Thủ thư chọn PATCH approve/reject → kiểm tra trạng thái → cập nhật hạn khi duyệt → thêm thông báo → trả JSON.
5. **Thống kê.** StatisticsPanel → gọi bốn endpoint song song → mỗi route kiểm tra vai trò và chạy truy vấn tổng hợp → Flutter nhận dữ liệu → dựng thẻ, biểu đồ và bảng xếp hạng.

### Cây widget để đối chiếu khi tự vẽ

| Màn hình | Thứ tự widget chính |
| --- | --- |
| Khởi động | MaterialApp → SplashPage → Scaffold → SafeArea → logo, tiến trình hoặc thử lại |
| Đăng nhập | LoginPage → Scaffold → SafeArea → LayoutBuilder → SingleChildScrollView → Form → TextFormField và ActionButton |
| Điều hướng | LibraryShell → LayoutBuilder → Scaffold → NavigationBar ở màn hình nhỏ hoặc NavigationRail ở màn hình rộng |
| Danh mục | BooksPage → PageFrame → DataPanel thể loại → bộ lọc → DataPanel sách → Collection → Card/ListTile/BookCover |
| Chi tiết sách | BookDetails → DataPanel → Collection → BookCover, thông tin và thao tác theo vai trò |
| Mượn trả | ActivityPage → CirculationPage → DataPanel → Collection → CirculationDetails → StatusTag và ActionButton |
| Thống kê | StatisticsPanel → DataPanel → Collection → MetricTiles, ChartCard, BarChart, PieChart và danh sách xếp hạng |
| Hồ sơ và cài đặt | AccountPage → ProfilePage hoặc SettingsPage → Collection → EditFields, DropdownButtonFormField và SwitchListTile |

Nhóm có thể dùng các actor, use case, bội số, class và thứ tự gọi ở trên để tự vẽ use case diagram, class diagram, sequence diagram và activity diagram bằng công cụ vẽ của lớp.
