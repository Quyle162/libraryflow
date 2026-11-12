CREATE DATABASE IF NOT EXISTS libraryflow_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE libraryflow_db;
SET NAMES utf8mb4;

CREATE TABLE users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  student_code VARCHAR(32) UNIQUE,
  email VARCHAR(254) NOT NULL UNIQUE,
  username VARCHAR(64) NOT NULL UNIQUE,
  password_hash VARCHAR(60) NOT NULL,
  role ENUM('reader','librarian') NOT NULL DEFAULT 'reader',
  status ENUM('active','locked') NOT NULL DEFAULT 'active',
  token_version INT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE categories (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(500) NOT NULL DEFAULT ''
) ENGINE=InnoDB;

CREATE TABLE books (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  book_code VARCHAR(32) NOT NULL UNIQUE,
  title VARCHAR(200) NOT NULL,
  author VARCHAR(160) NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  publisher VARCHAR(160) NOT NULL,
  published_year SMALLINT UNSIGNED NOT NULL CHECK (published_year >= 1000),
  isbn VARCHAR(20) UNIQUE,
  description TEXT NOT NULL,
  cover_image VARCHAR(500),
  total_copies INT UNSIGNED NOT NULL,
  available_copies INT UNSIGNED NOT NULL,
  status ENUM('active','archived') NOT NULL DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (category_id) REFERENCES categories(id),
  CHECK (available_copies <= total_copies),
  INDEX (status, title),
  INDEX (status, published_year)
) ENGINE=InnoDB;

CREATE TABLE borrow_requests (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  book_id INT UNSIGNED NOT NULL,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_by INT UNSIGNED,
  reviewed_at DATETIME,
  rejection_reason VARCHAR(500),
  pending_book INT UNSIGNED GENERATED ALWAYS AS (IF(status='pending',book_id,NULL)) STORED,
  UNIQUE (user_id,pending_book),
  UNIQUE (id,user_id,book_id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (book_id) REFERENCES books(id),
  FOREIGN KEY (reviewed_by) REFERENCES users(id),
  INDEX (status,requested_at)
) ENGINE=InnoDB;

CREATE TABLE borrow_records (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  book_id INT UNSIGNED NOT NULL,
  borrow_request_id INT UNSIGNED NOT NULL UNIQUE,
  borrowed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  due_at DATETIME NOT NULL,
  returned_at DATETIME,
  status ENUM('active','returned') NOT NULL DEFAULT 'active',
  renewal_count TINYINT UNSIGNED NOT NULL DEFAULT 0 CHECK (renewal_count <= 1),
  active_book INT UNSIGNED GENERATED ALWAYS AS (IF(status='active',book_id,NULL)) STORED,
  UNIQUE (user_id,active_book),
  UNIQUE (id,user_id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (book_id) REFERENCES books(id),
  FOREIGN KEY (borrow_request_id,user_id,book_id) REFERENCES borrow_requests(id,user_id,book_id),
  CHECK ((status='returned') = (returned_at IS NOT NULL)),
  INDEX (user_id,status),
  INDEX (status,due_at),
  INDEX (borrowed_at)
) ENGINE=InnoDB ;

CREATE TABLE renewal_requests (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  borrow_record_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_by INT UNSIGNED,
  reviewed_at DATETIME,
  rejection_reason VARCHAR(500),
  pending_record INT UNSIGNED GENERATED ALWAYS AS (IF(status='pending',borrow_record_id,NULL)) STORED UNIQUE,
  FOREIGN KEY (borrow_record_id,user_id) REFERENCES borrow_records(id,user_id),
  FOREIGN KEY (reviewed_by) REFERENCES users(id),
  INDEX (status,requested_at)
) ENGINE=InnoDB;

CREATE TABLE notifications (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  kind ENUM('borrow_approved','borrow_rejected','renewal_approved','renewal_rejected','due_soon','overdue') NOT NULL,
  title VARCHAR(120) NOT NULL,
  message VARCHAR(500) NOT NULL,
  book_title VARCHAR(200) NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  event_key VARCHAR(100) UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX (user_id,is_read,created_at)
) ENGINE=InnoDB;

CREATE TABLE activity_logs (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  action VARCHAR(64) NOT NULL,
  description VARCHAR(500) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;
