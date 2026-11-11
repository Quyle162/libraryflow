import 'dotenv/config';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { readFile } from 'node:fs/promises';
import { randomBytes } from 'node:crypto';
import { test } from 'node:test';
import mysql from 'mysql2/promise';

test('API tích hợp với schema và seed MySQL thật', {
  skip: process.env.LIBRARYFLOW_INTEGRATION !== '1',
}, async t => {
  // Mỗi lần chạy có database riêng. Không chạy UPDATE/DELETE lên database ứng dụng.
  const name = 'libraryflow_test_' + randomBytes(8).toString('hex');
  const db = await mysql.createConnection({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    multipleStatements: true,
  });
  let server;
  let pool;
  t.after(async () => {
    if (server) await new Promise(resolve => server.close(resolve));
    if (pool) await pool.end();
    await db.query('DROP DATABASE IF EXISTS ' + name);
    await db.end();
  });
  for (const file of ['database.sql', 'seed.sql']) {
    const script = await readFile(new URL('../../database/' + file, import.meta.url), 'utf8');
    await db.query(script.replaceAll('libraryflow_db', name));
  }
  process.env.DB_NAME = name;
  ({ pool } = await import('../src/db.js'));
  const { createApp } = await import('../src/app.js');
  server = createApp('libraryflow-isolated-integration-test').listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = 'http://127.0.0.1:' + server.address().port + '/api';

  async function call(path, { token, method = 'GET', body, status = 200 } = {}) {
    const response = await fetch(base + path, {
      method,
      headers: {
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      body: body && JSON.stringify(body),
    });
    const result = await response.json();
    assert.equal(response.status, status, method + ' ' + path + ' ' + JSON.stringify(result));
    return status < 400 ? result.data : result.error;
  }
  const password = 'Demo@123456';
  const login = (name, pass = password, status = 200) => call('/auth/login', {
    method: 'POST', body: { login: name, password: pass }, status,
  });
  const librarian = (await login('thuthu@libraryflow.test')).token;
  const { token: reader, user } = await login('sv01');
  const readerTwo = (await login('sv02')).token;
  const readerFour = (await login('sv04')).token;
  assert.equal(user.password_hash, undefined);

  await t.test('đăng nhập, phân quyền và đọc danh mục', async () => {
    await call('/health');
    await login('sv05', password, 403);
    await login('sv01', 'incorrect', 401);
    await call('/statistics/overview', { token: reader, status: 403 });
    await call('/borrow-records', { token: reader, status: 403 });
    await call('/users/3', { token: reader, status: 403 });
    await call('/books', { token: reader, method: 'POST', body: {}, status: 403 });
    await call('/books/invalid', { token: reader, status: 400 });
    assert.equal((await call('/auth/me', { token: reader })).id, 2);
    assert.equal((await call('/books', { token: reader })).length, 20);
    assert.equal((await call('/books?category_id=1&sort=year', { token: reader })).length, 4);
    assert.equal((await call('/books?q=Dart', { token: reader })).length, 1);
    const cover = await fetch(base + '/covers/LF001.webp');
    assert.equal(cover.status, 200);
    assert.equal(cover.headers.get('content-type'), 'image/webp');
  });

  await t.test('CRUD sách và thể loại, giữ quan hệ dữ liệu', async () => {
    const { id: categoryId } = await call('/categories', { token: librarian, method: 'POST',
      body: { name: 'Thể loại kiểm thử' }, status: 201 });
    await call('/categories/' + categoryId, { token: librarian, method: 'PUT', body: { name: 'Thể loại đã sửa' } });
    const draft = { book_code: 'TEST-01', title: 'Sách kiểm thử', author: 'Tác giả', category_id: categoryId,
      publisher: 'Nhà xuất bản', published_year: 2024, total_copies: 1 };
    const { id } = await call('/books', { token: librarian, method: 'POST', body: draft, status: 201 });
    await call('/books/' + id, { token: librarian, method: 'PUT', body: { ...draft, total_copies: 2 } });
    assert.equal((await call('/books/' + id, { token: reader })).available_copies, 2);
    await call('/categories/' + categoryId, { token: librarian, method: 'DELETE', status: 409 });
    await call('/books/' + id, { token: librarian, method: 'DELETE' });
    await call('/books/' + id, { token: reader, status: 404 });
    await call('/books/' + id + '/restore', { token: librarian, method: 'PATCH' });
    assert.equal((await call('/books/' + id, { token: reader })).status, 'active');
    const unused = await call('/categories', { token: librarian, method: 'POST',
      body: { name: 'Có thể xóa' }, status: 201 });
    await call('/categories/' + unused.id, { token: librarian, method: 'DELETE' });
  });

  await t.test('duyệt mượn đồng thời, giới hạn 3, kiểm tra tồn kho và trả một lần', async () => {
    const newRequest = await call('/borrow-requests', {
      token: reader, method: 'POST', body: { book_id: 8 }, status: 201,
    });
    await call('/borrow-requests', { token: reader, method: 'POST', body: { book_id: 8 }, status: 409 });
    await call('/borrow-requests/5/approve', { token: reader, method: 'PATCH', status: 403 });
    const statuses = await Promise.all([5, newRequest.id].map(id =>
      fetch(base + '/borrow-requests/' + id + '/approve', {
        method: 'PATCH', headers: { Authorization: 'Bearer ' + librarian },
      }).then(response => response.status)));
    assert.deepEqual(statuses.sort(), [200, 409]);
    const loans = await call('/borrow-records/my', { token: reader });
    assert.equal(loans.filter(row => row.status === 'active').length, 3);
    const loan = loans.find(row => [5, 8].includes(row.book_id));
    assert.equal(Date.parse(loan.due_at) - Date.parse(loan.borrowed_at), 14 * 86400000);
    const requestList = await call('/borrow-requests', { token: reader });
    assert(requestList.every(row => row.student_code === 'SV001'));
    await call('/borrow-requests', { token: reader, method: 'POST', body: { book_id: 9 }, status: 409 });
    const book = await call('/books/' + loan.book_id, { token: reader });
    assert.equal(book.available_copies, 3);
    await call('/books/' + book.id, { token: librarian, method: 'PUT', body: { ...book, total_copies: 0 }, status: 409 });
    await call('/borrow-records/' + loan.id + '/return', { token: librarian, method: 'PATCH' });
    await call('/borrow-records/' + loan.id + '/return', { token: librarian, method: 'PATCH', status: 409 });
    assert.equal((await call('/books/' + book.id, { token: reader })).available_copies, 4);
    const remaining = requestList.find(row => row.status === 'pending');
    await call('/borrow-requests/' + remaining.id + '/reject', {
      token: librarian, method: 'PATCH', body: { reason: 'Dữ liệu kiểm thử' },
    });
    const [mismatches] = await db.query(`SELECT b.id FROM books b WHERE b.total_copies-b.available_copies <>
      (SELECT COUNT(*) FROM borrow_records r WHERE r.book_id=b.id AND r.status='active')`);
    assert.deepEqual(mismatches, []);
  });

  await t.test('gia hạn, quá hạn, thông báo, thống kê và vô hiệu hóa phiên', async () => {
    const before = (await call('/borrow-records/my', { token: reader })).find(row => row.id === 3);
    await call('/renewal-requests', { token: reader, method: 'POST', body: { borrow_record_id: 3 }, status: 409 });
    await call('/renewal-requests', { token: reader, method: 'POST', body: { borrow_record_id: 2 }, status: 404 });
    await call('/renewal-requests', { token: readerTwo, method: 'POST', body: { borrow_record_id: 2 }, status: 409 });
    await call('/renewal-requests/1/approve', { token: librarian, method: 'PATCH' });
    const after = (await call('/borrow-records/my', { token: reader })).find(row => row.id === 3);
    assert.equal(Date.parse(after.due_at) - Date.parse(before.due_at), 7 * 86400000);
    assert.equal(after.renewal_count, 1);
    await call('/renewal-requests', { token: reader, method: 'POST', body: { borrow_record_id: 3 }, status: 409 });

    const first = await call('/notifications', { token: reader });
    const again = await call('/notifications', { token: reader });
    assert.equal(first.items.length, again.items.length);
    assert(first.items.some(row => row.kind === 'due_soon'));
    assert(first.items.some(row => row.kind === 'renewal_approved'));
    const overdue = await call('/notifications', { token: readerTwo });
    assert(overdue.items.some(row => row.kind === 'overdue'));
    await call('/notifications/' + first.items[0].id + '/read', { token: readerTwo, method: 'PATCH', status: 404 });
    await call('/notifications/' + first.items[0].id + '/read', { token: reader, method: 'PATCH' });
    assert.equal((await call('/notifications', { token: reader })).unread, first.unread - 1);
    assert.equal((await call('/statistics/overview', { token: librarian })).overdue, 1);
    assert.equal((await call('/statistics/borrow-by-month', { token: librarian })).length, 12);
    assert.equal((await call('/statistics/books-by-category', { token: librarian })).length, 6);
    assert((await call('/statistics/popular-books', { token: librarian })).length <= 5);
    assert.equal((await call('/users?q=SV001', { token: librarian }))[0].active_loans, 2);
    assert((await call('/users/2', { token: librarian })).records.length >= 3);
    await call('/users/5/status', { token: librarian, method: 'PATCH', body: { status: 'locked' } });
    await call('/auth/me', { token: readerFour, status: 401 });
    await call('/users/5/status', { token: librarian, method: 'PATCH', body: { status: 'active' } });
    await login('sv04');
    await call('/users/2', { token: reader, method: 'PUT', body: { full_name: 'Tên kiểm thử', email: user.email } });
    assert.equal((await call('/auth/me', { token: reader })).full_name, 'Tên kiểm thử');
    await call('/auth/change-password', { token: reader, method: 'PUT',
      body: { current_password: password, new_password: 'Changed@12345' } });
    await call('/auth/me', { token: reader, status: 401 });
    await login('sv01', 'Changed@12345');
  });
});
