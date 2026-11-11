USE libraryflow_db;
SET NAMES utf8mb4;
SET time_zone = '+00:00';
START TRANSACTION;
SET @demo_hash = '$2b$10$UxTSd4P5qcy6Uz4aNhUZaeIuCjvwaICHOD/LHs98FX9yrLvjroH82';
INSERT INTO users (id,full_name,student_code,email,username,password_hash,role,status) VALUES
(1,'Lê Minh Anh',NULL,'thuthu@libraryflow.test','thuthu',@demo_hash,'librarian','active'),
(2,'Nguyễn Hoàng Nam','SV001','sv01@libraryflow.test','sv01',@demo_hash,'reader','active'),
(3,'Trần Ngọc Linh','SV002','sv02@libraryflow.test','sv02',@demo_hash,'reader','active'),
(4,'Phạm Gia Hân','SV003','sv03@libraryflow.test','sv03',@demo_hash,'reader','active'),
(5,'Đỗ Đức Minh','SV004','sv04@libraryflow.test','sv04',@demo_hash,'reader','active'),
(6,'Vũ Thanh Hà','SV005','sv05@libraryflow.test','sv05',@demo_hash,'reader','locked');
INSERT INTO categories (id,name,description) VALUES
(1,'Công nghệ','Lập trình và hệ thống'),
(2,'Văn học','Tiểu thuyết và truyện ngắn'),
(3,'Khoa học','Kiến thức khoa học phổ thông'),
(4,'Kinh tế','Kinh tế học và kinh doanh'),
(5,'Kỹ năng','Học tập và làm việc');
INSERT INTO books (id,book_code,title,author,category_id,publisher,published_year,description,cover_image,total_copies,available_copies) VALUES
(1,'LF001','Nhập môn lập trình Dart','Nguyễn Minh Tâm',1,'NXB demo',2016,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF001.webp',4,3),
(2,'LF002','Cơ sở dữ liệu thực hành','Lê Văn Sơn',1,'NXB demo',2017,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF002.webp',4,3),
(3,'LF003','Phát triển ứng dụng Flutter','Trần Ngọc An',1,'NXB demo',2018,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF003.webp',4,3),
(4,'LF004','Thiết kế REST API','Phạm Hoàng Long',1,'NXB demo',2019,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF004.webp',4,4),
(5,'LF005','Dế Mèn phiêu lưu ký','Tô Hoài',2,'NXB demo',2020,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF005.webp',4,4),
(6,'LF006','Cho tôi xin một vé đi tuổi thơ','Nguyễn Nhật Ánh',2,'NXB demo',2021,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF006.webp',4,4),
(7,'LF007','Đất rừng phương Nam','Đoàn Giỏi',2,'NXB demo',2022,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF007.webp',4,4),
(8,'LF008','Hai đứa trẻ','Thạch Lam',2,'NXB demo',2023,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF008.webp',4,4),
(9,'LF009','Bầu trời đêm','Lê Thu Hà',3,'NXB demo',2024,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF009.webp',4,4),
(10,'LF010','Khám phá đại dương','Vũ Minh Đức',3,'NXB demo',2015,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF010.webp',4,4),
(11,'LF011','Vật lý quanh ta','Trần Lan Anh',3,'NXB demo',2016,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF011.webp',4,4),
(12,'LF012','Thế giới thực vật','Nguyễn Hồng Nhung',3,'NXB demo',2017,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF012.webp',4,4),
(13,'LF013','Nhập môn kinh tế học','Lê Anh Tuấn',4,'NXB demo',2018,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF013.webp',4,4),
(14,'LF014','Kinh tế số','Phạm Thảo Linh',4,'NXB demo',2019,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF014.webp',4,4),
(15,'LF015','Quản trị doanh nghiệp','Vũ Hà My',4,'NXB demo',2020,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF015.webp',4,4),
(16,'LF016','Tài chính cá nhân','Trần Quang Minh',4,'NXB demo',2021,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF016.webp',4,4),
(17,'LF017','Kỹ năng làm việc nhóm','Đặng Hải Yến',5,'NXB demo',2022,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF017.webp',4,4),
(18,'LF018','Phương pháp tự học','Nguyễn Đức Hải',5,'NXB demo',2023,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF018.webp',4,4),
(19,'LF019','Nghệ thuật thuyết trình','Phạm Hoài An',5,'NXB demo',2024,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF019.webp',4,4),
(20,'LF020','Quản lý thời gian','Lê Bảo Ngọc',5,'NXB demo',2015,'Đầu sách mẫu thuộc danh mục thư viện.','/covers/LF020.webp',4,4);
INSERT INTO borrow_requests (id,user_id,book_id,status,requested_at,reviewed_by,reviewed_at,rejection_reason) VALUES
(1,2,1,'approved',NOW()-INTERVAL 12 DAY,1,NOW()-INTERVAL 12 DAY,NULL),
(2,3,2,'approved',NOW()-INTERVAL 19 DAY,1,NOW()-INTERVAL 19 DAY,NULL),
(3,2,3,'approved',NOW()-INTERVAL 4 DAY,1,NOW()-INTERVAL 4 DAY,NULL),
(4,2,4,'approved',NOW()-INTERVAL 40 DAY,1,NOW()-INTERVAL 40 DAY,NULL),
(5,2,5,'pending',NOW(),NULL,NULL,NULL),
(6,4,6,'rejected',NOW()-INTERVAL 2 DAY,1,NOW()-INTERVAL 1 DAY,'Độc giả đề nghị hủy.'),
(7,5,7,'pending',NOW(),NULL,NULL,NULL);
INSERT INTO borrow_records (id,user_id,book_id,borrow_request_id,borrowed_at,due_at,returned_at,status) VALUES
(1,2,1,1,NOW()-INTERVAL 12 DAY,NOW()+INTERVAL 2 DAY,NULL,'active'),
(2,3,2,2,NOW()-INTERVAL 19 DAY,NOW()-INTERVAL 5 DAY,NULL,'active'),
(3,2,3,3,NOW()-INTERVAL 4 DAY,NOW()+INTERVAL 10 DAY,NULL,'active'),
(4,2,4,4,NOW()-INTERVAL 40 DAY,NOW()-INTERVAL 26 DAY,NOW()-INTERVAL 30 DAY,'returned');
INSERT INTO renewal_requests (borrow_record_id,user_id) VALUES (3,2);
INSERT INTO notifications (user_id,kind,title,message,book_title) VALUES
(2,'borrow_approved','Yêu cầu mượn đã được duyệt','Nhập môn lập trình Dart','Nhập môn lập trình Dart'),
(4,'borrow_rejected','Yêu cầu mượn bị từ chối','Cho tôi xin một vé đi tuổi thơ','Cho tôi xin một vé đi tuổi thơ');
COMMIT;
