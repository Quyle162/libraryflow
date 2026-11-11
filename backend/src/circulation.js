import { librarian, reader } from './auth.js';
import { pool, query, one, transaction } from './db.js';
import { found, id, ok, requireThat, string } from './http.js';

const conflict = (condition, code, message) => requireThat(condition, 409, code, message);
const active = (db, userId) => one(db, "SELECT id,status FROM users WHERE id=? AND role='reader' FOR UPDATE", [userId]);
const lockBook = (db, bookId) => one(db, 'SELECT * FROM books WHERE id=? FOR UPDATE', [bookId]);
const pending = row => conflict(row.status === 'pending', 'already_reviewed', 'Yêu cầu đã được xử lý.');
const eligibility = async (db, user, book) => {
  conflict(user?.status === 'active', 'locked', 'Tài khoản đang bị khóa.');
  conflict(book.status === 'active' && book.available_copies > 0, 'unavailable', 'Sách hiện không khả dụng.');
  const loans = await query(db, "SELECT book_id FROM borrow_records WHERE user_id=? AND status='active'", [user.id]);
  conflict(!loans.some(row => row.book_id === book.id), 'duplicate_loan', 'Bạn đang mượn đầu sách này.');
  conflict(loans.length < 3, 'loan_limit', 'Độc giả đã mượn tối đa 3 cuốn.');
};
const log = (db, userId, action, target) => query(db,
  'INSERT INTO activity_logs (user_id,action,description) VALUES (?,?,?)', [userId, action, String(target)]);
const notify = (db, userId, kind, title, bookTitle) => query(db,
  'INSERT INTO notifications (user_id,kind,title,message,book_title) VALUES (?,?,?,?,?)',
  [userId, kind, title, bookTitle, bookTitle]);
const rejection = (req, approve) => approve ? null : string(req.body?.reason, 'lý do', 500, true) || null;

const recordSelect = `SELECT r.id,r.user_id,r.book_id,r.borrowed_at,r.due_at,r.returned_at,r.status,
  r.renewal_count,b.title,u.full_name,u.student_code,u.email,
  CASE WHEN r.status='returned' THEN 'returned'
    WHEN r.due_at < UTC_TIMESTAMP() THEN 'overdue'
    WHEN r.due_at <= UTC_TIMESTAMP()+INTERVAL 3 DAY THEN 'due_soon' ELSE 'active' END AS loan_state,
  CASE WHEN r.status='active' AND r.due_at < UTC_TIMESTAMP()
    THEN CEIL(TIMESTAMPDIFF(SECOND,r.due_at,UTC_TIMESTAMP())/86400) ELSE 0 END AS overdue_days,
  EXISTS(SELECT 1 FROM renewal_requests e WHERE e.borrow_record_id=r.id AND e.status='pending') AS renewal_pending
  FROM borrow_records r JOIN books b ON b.id=r.book_id JOIN users u ON u.id=r.user_id`;

async function reviewBorrow(req, approve) {
  const requestId = id(req.params.id);
  const reason = rejection(req, approve);
  await transaction(async db => {
    const identity = found(await one(db, 'SELECT user_id,book_id FROM borrow_requests WHERE id=?', [requestId]));
    // Khóa theo thứ tự độc giả → sách → yêu cầu để tuần tự hóa giới hạn mượn và tồn kho.
    const user = await active(db, identity.user_id);
    const book = found(await lockBook(db, identity.book_id));
    pending(found(await one(db, 'SELECT status FROM borrow_requests WHERE id=? FOR UPDATE', [requestId])));
    if (approve) {
      await eligibility(db, user, book);
      await query(db, `INSERT INTO borrow_records (user_id,book_id,borrow_request_id,due_at)
        VALUES (?,?,?,UTC_TIMESTAMP()+INTERVAL 14 DAY)`, [user.id, book.id, requestId]);
      await query(db, 'UPDATE books SET available_copies=available_copies-1 WHERE id=?', [book.id]);
    }
    const status = approve ? 'approved' : 'rejected';
    await query(db, `UPDATE borrow_requests SET status=?,reviewed_by=?,reviewed_at=UTC_TIMESTAMP(),
      rejection_reason=? WHERE id=?`, [status, req.user.id, reason, requestId]);
    await notify(db, identity.user_id, 'borrow_' + status,
      approve ? 'Yêu cầu mượn đã được duyệt' : 'Yêu cầu mượn bị từ chối', book.title);
    await log(db, req.user.id, 'borrow_' + status, requestId);
  });
}

function canRenew(record) {
  conflict(record.status === 'active' && !record.overdue, 'not_renewable', 'Phiếu đã trả hoặc quá hạn.');
  conflict(record.renewal_count === 0, 'renewal_limit', 'Phiếu đã được gia hạn một lần.');
}

const lockRecord = (db, recordId) => one(db, `SELECT *,due_at < UTC_TIMESTAMP() AS overdue
  FROM borrow_records WHERE id=? FOR UPDATE`, [recordId]);

async function reviewRenewal(req, approve) {
  const renewalId = id(req.params.id);
  const reason = rejection(req, approve);
  await transaction(async db => {
    const identity = found(await one(db, 'SELECT user_id,borrow_record_id FROM renewal_requests WHERE id=?', [renewalId]));
    const user = await active(db, identity.user_id);
    const record = found(await lockRecord(db, identity.borrow_record_id));
    pending(found(await one(db, 'SELECT status FROM renewal_requests WHERE id=? FOR UPDATE', [renewalId])));
    if (approve) {
      conflict(user?.status === 'active', 'locked', 'Tài khoản đang bị khóa.');
      canRenew(record);
      await query(db, 'UPDATE borrow_records SET due_at=due_at+INTERVAL 7 DAY,renewal_count=1 WHERE id=?', [record.id]);
    }
    const status = approve ? 'approved' : 'rejected';
    await query(db, `UPDATE renewal_requests SET status=?,reviewed_by=?,reviewed_at=UTC_TIMESTAMP(),
      rejection_reason=? WHERE id=?`, [status, req.user.id, reason, renewalId]);
    const { title } = await one(db, 'SELECT title FROM books WHERE id=?', [record.book_id]);
    await notify(db, identity.user_id, 'renewal_' + status,
      approve ? 'Yêu cầu gia hạn đã được duyệt' : 'Yêu cầu gia hạn bị từ chối', title);
    await log(db, req.user.id, 'renewal_' + status, renewalId);
  });
}

export function circulationRoutes(app) {
  app.post('/api/borrow-requests', reader, async (req, res) => {
    const bookId = id(req.body?.book_id);
    const result = await transaction(async db => {
      const user = await active(db, req.user.id);
      const book = found(await lockBook(db, bookId));
      await eligibility(db, user, book);
      return query(db, 'INSERT INTO borrow_requests (user_id,book_id) VALUES (?,?)', [user.id, book.id]);
    });
    ok(res, { id: result.insertId }, 201);
  });
  app.get('/api/borrow-requests', async (req, res) => {
    ok(res, await query(pool, `SELECT q.id,q.status,q.requested_at,q.reviewed_at,q.rejection_reason,
      b.title,u.full_name,u.student_code FROM borrow_requests q JOIN books b ON b.id=q.book_id
      JOIN users u ON u.id=q.user_id WHERE (?='librarian' OR q.user_id=?)
      ORDER BY (q.status='pending') DESC,q.id DESC`, [req.user.role, req.user.id]));
  });

  app.get('/api/borrow-records/my', reader, async (req, res) =>
    ok(res, await query(pool, recordSelect + ' WHERE r.user_id=? ORDER BY r.id DESC', [req.user.id])));
  app.get('/api/borrow-records', librarian, async (req, res) =>
    ok(res, await query(pool, recordSelect + ' ORDER BY r.id DESC')));

  app.patch('/api/borrow-records/:id/return', librarian, async (req, res) => {
    const recordId = id(req.params.id);
    await transaction(async db => {
      const identity = found(await one(db, 'SELECT user_id,book_id FROM borrow_records WHERE id=?', [recordId]));
      await active(db, identity.user_id);
      const book = found(await lockBook(db, identity.book_id));
      const record = found(await lockRecord(db, recordId));
      conflict(record.status === 'active', 'already_returned', 'Phiếu đã được trả.');
      await query(db, "UPDATE borrow_records SET status='returned',returned_at=UTC_TIMESTAMP() WHERE id=?", [recordId]);
      await query(db, 'UPDATE books SET available_copies=available_copies+1 WHERE id=?', [book.id]);
      const renewal = await one(db, "SELECT id FROM renewal_requests WHERE borrow_record_id=? AND status='pending'", [recordId]);
      if (renewal) {
        await query(db, `UPDATE renewal_requests SET status='rejected',reviewed_by=?,reviewed_at=UTC_TIMESTAMP(),
          rejection_reason='Phiếu đã trả' WHERE id=?`, [req.user.id, renewal.id]);
        await notify(db, identity.user_id, 'renewal_rejected', 'Yêu cầu gia hạn bị từ chối', book.title);
        await log(db, req.user.id, 'renewal_rejected', renewal.id);
      }
      await log(db, req.user.id, 'return', recordId);
    });
    ok(res, null);
  });

  app.post('/api/renewal-requests', reader, async (req, res) => {
    const recordId = id(req.body?.borrow_record_id);
    const result = await transaction(async db => {
      const user = await active(db, req.user.id);
      conflict(user?.status === 'active', 'locked', 'Tài khoản đang bị khóa.');
      const record = found(await one(db, `SELECT *,due_at < UTC_TIMESTAMP() AS overdue
        FROM borrow_records WHERE id=? AND user_id=? FOR UPDATE`, [recordId, user.id]));
      canRenew(record);
      return query(db, 'INSERT INTO renewal_requests (borrow_record_id,user_id) VALUES (?,?)', [recordId, user.id]);
    });
    ok(res, { id: result.insertId }, 201);
  });
  app.get('/api/renewal-requests', async (req, res) => {
    ok(res, await query(pool, `SELECT q.id,q.status,q.requested_at,q.reviewed_at,q.rejection_reason,
      b.title,u.full_name,u.student_code,r.due_at FROM renewal_requests q JOIN borrow_records r ON r.id=q.borrow_record_id
      JOIN books b ON b.id=r.book_id JOIN users u ON u.id=q.user_id
      WHERE (?='librarian' OR q.user_id=?) ORDER BY (q.status='pending') DESC,q.id DESC`, [req.user.role, req.user.id]));
  });
  for (const [action, approve] of [['approve', true], ['reject', false]]) {
    app.patch('/api/borrow-requests/:id/' + action, librarian, async (req, res) => {
      await reviewBorrow(req, approve);
      ok(res, null);
    });
    app.patch('/api/renewal-requests/:id/' + action, librarian, async (req, res) => {
      await reviewRenewal(req, approve);
      ok(res, null);
    });
  }
}
