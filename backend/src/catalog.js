import { pool, query, one, transaction } from './db.js';
import { librarian, publicUser } from './auth.js';
import { found, id, integer, invalid, ok, requireThat, string } from './http.js';

const bookSelect = 'SELECT b.*, c.name AS category_name FROM books b JOIN categories c ON c.id=b.category_id';

function bookFields(body) {
  const cover = string(body?.cover_image, 'ảnh bìa', 500, true);
  if (cover && !/^\/covers\/LF\d{3}\.webp$/.test(cover) && !/^https?:\/\/[^\s/]+[^\s]*$/i.test(cover)) invalid('ảnh bìa');
  return [
    string(body?.book_code, 'mã sách', 32),
    string(body?.title, 'tên sách', 200),
    string(body?.author, 'tác giả', 160),
    id(body?.category_id),
    string(body?.publisher, 'nhà xuất bản', 160),
    integer(body?.published_year, 'năm xuất bản', 1000, new Date().getFullYear()),
    string(body?.isbn, 'ISBN', 20, true) || null,
    string(body?.description, 'mô tả', 5000, true),
    cover || null,
    integer(body?.total_copies, 'tổng số bản', 0, 100000),
  ];
}

export function catalogRoutes(app) {
  app.get('/api/books', async (req, res) => {
    const search = string(req.query.q, 'tìm kiếm', 200, true);
    const category = req.query.category_id ? id(req.query.category_id) : null;
    const status = req.user.role === 'librarian' && req.query.archived === '1' ? 'archived' : 'active';
    const order = req.query.sort === 'year' ? 'b.published_year DESC,b.title,b.id' : 'b.title,b.id';
    ok(res, await query(pool, `${bookSelect} WHERE b.status=?
      AND (LOCATE(?,b.title)>0 OR LOCATE(?,b.author)>0 OR ?='')
      AND (? IS NULL OR b.category_id=?) ORDER BY ${order}`,
    [status, search, search, search, category, category]));
  });
  app.get('/api/books/:id', async (req, res) => {
    const book = found(await one(pool, `${bookSelect} WHERE b.id=? AND (b.status='active' OR ?='librarian')`,
      [id(req.params.id), req.user.role]));
    ok(res, book);
  });
  app.post('/api/books', librarian, async (req, res) => {
    const fields = bookFields(req.body);
    const result = await query(pool, `INSERT INTO books (book_code,title,author,category_id,publisher,
      published_year,isbn,description,cover_image,total_copies,available_copies)
      VALUES (?,?,?,?,?,?,?,?,?,?,?)`, [...fields, fields[9]]);
    ok(res, { id: result.insertId }, 201);
  });
  app.put('/api/books/:id', librarian, async (req, res) => {
    const bookId = id(req.params.id);
    const fields = bookFields(req.body);
    await transaction(async db => {
      const book = found(await one(db, 'SELECT total_copies,available_copies FROM books WHERE id=? FOR UPDATE', [bookId]));
      const borrowed = book.total_copies - book.available_copies;
      requireThat(fields[9] >= borrowed, 409, 'stock_below_borrowed', 'Tổng số bản nhỏ hơn số bản đang mượn.');
      await query(db, `UPDATE books SET book_code=?,title=?,author=?,category_id=?,publisher=?,
        published_year=?,isbn=?,description=?,cover_image=?,total_copies=?,available_copies=? WHERE id=?`,
      [...fields, fields[9] - borrowed, bookId]);
    });
    ok(res, { id: bookId });
  });
  app.delete('/api/books/:id', librarian, async (req, res) => {
    found((await query(pool, "UPDATE books SET status='archived' WHERE id=?", [id(req.params.id)])).affectedRows);
    ok(res, null);
  });
  app.patch('/api/books/:id/restore', librarian, async (req, res) => {
    found((await query(pool, "UPDATE books SET status='active' WHERE id=?", [id(req.params.id)])).affectedRows);
    ok(res, null);
  });

  app.get('/api/categories', async (req, res) => ok(res, await query(pool, 'SELECT * FROM categories ORDER BY name')));
  const categoryFields = body => [string(body?.name, 'tên thể loại', 100), string(body?.description, 'mô tả', 500, true)];
  app.post('/api/categories', librarian, async (req, res) => {
    const result = await query(pool, 'INSERT INTO categories (name,description) VALUES (?,?)', categoryFields(req.body));
    ok(res, { id: result.insertId }, 201);
  });
  app.put('/api/categories/:id', librarian, async (req, res) => {
    const categoryId = id(req.params.id);
    found((await query(pool, 'UPDATE categories SET name=?,description=? WHERE id=?', [...categoryFields(req.body), categoryId])).affectedRows);
    ok(res, { id: categoryId });
  });
  app.delete('/api/categories/:id', librarian, async (req, res) => {
    found((await query(pool, 'DELETE FROM categories WHERE id=?', [id(req.params.id)])).affectedRows);
    ok(res, null);
  });

  app.get('/api/users', librarian, async (req, res) => {
    const search = string(req.query.q, 'tìm kiếm', 200, true);
    ok(res, await query(pool, `SELECT ${publicUser}, (SELECT COUNT(*) FROM borrow_records r
      WHERE r.user_id=users.id AND r.status='active') AS active_loans FROM users
      WHERE role='reader' AND (?='' OR LOCATE(?,full_name)>0 OR LOCATE(?,student_code)>0
      OR LOCATE(?,email)>0 OR LOCATE(?,username)>0) ORDER BY full_name,id`,
    [search, search, search, search, search]));
  });
  app.get('/api/users/:id', librarian, async (req, res) => {
    const userId = id(req.params.id);
    const profile = found(await one(pool, `SELECT ${publicUser} FROM users WHERE id=? AND role='reader'`, [userId]));
    const records = await query(pool, `SELECT r.id,r.borrowed_at,r.due_at,r.returned_at,r.status,b.title
      FROM borrow_records r JOIN books b ON b.id=r.book_id WHERE r.user_id=? ORDER BY r.id DESC`, [userId]);
    ok(res, { ...profile, active_loans: records.filter(row => row.status === 'active').length, records });
  });
  app.put('/api/users/:id', async (req, res) => {
    const userId = id(req.params.id);
    requireThat(userId === req.user.id || req.user.role === 'librarian', 403, 'forbidden', 'Bạn không có quyền thực hiện.');
    const email = string(req.body?.email, 'email', 254);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) invalid('email');
    found((await query(pool, 'UPDATE users SET full_name=?,email=? WHERE id=? AND (id=? OR role=\'reader\')',
      [string(req.body?.full_name, 'họ tên', 120), email, userId, req.user.id])).affectedRows);
    ok(res, await one(pool, `SELECT ${publicUser} FROM users WHERE id=?`, [userId]));
  });
  app.patch('/api/users/:id/status', librarian, async (req, res) => {
    const status = req.body?.status;
    if (!['locked', 'active'].includes(status)) invalid('trạng thái');
    const userId = id(req.params.id);
    await transaction(async db => {
      const user = found(await one(db, "SELECT status FROM users WHERE id=? AND role='reader' FOR UPDATE", [userId]));
      if (user.status !== status) {
        await query(db, 'UPDATE users SET status=?,token_version=token_version+1 WHERE id=?', [status, userId]);
        await query(db, 'INSERT INTO activity_logs (user_id,action,description) VALUES (?,?,?)',
          [req.user.id, 'reader_' + status, String(userId)]);
      }
    });
    ok(res, null);
  });
}
