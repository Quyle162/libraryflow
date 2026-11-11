import { librarian } from './auth.js';
import { pool, query, one } from './db.js';
import { found, id, ok } from './http.js';

// Một thông báo cho mỗi mốc của từng hạn trả, kể cả khi ứng dụng mở nhiều lần.
export async function generateReminders() {
  await query(pool, `INSERT INTO notifications (user_id,kind,title,message,book_title,event_key)
    SELECT r.user_id, IF(r.due_at<UTC_TIMESTAMP(),'overdue','due_soon'),
      IF(r.due_at<UTC_TIMESTAMP(),'Sách đã quá hạn','Sách sắp đến hạn'),
      b.title,b.title,CONCAT(r.id,':',r.due_at,':',IF(r.due_at<UTC_TIMESTAMP(),'late','soon'))
    FROM borrow_records r JOIN books b ON b.id=r.book_id
    WHERE r.status='active' AND r.due_at<=UTC_TIMESTAMP()+INTERVAL 3 DAY
    ON DUPLICATE KEY UPDATE event_key=notifications.event_key`);
}

export function reportingRoutes(app) {
  app.get('/api/notifications', async (req, res) => {
    await generateReminders();
    const items = await query(pool, `SELECT id,kind,title,message,book_title,is_read,created_at
      FROM notifications WHERE user_id=? ORDER BY id DESC`, [req.user.id]);
    ok(res, { items, unread: items.filter(item => !item.is_read).length });
  });
  app.patch('/api/notifications/:id/read', async (req, res) => {
    found((await query(pool, 'UPDATE notifications SET is_read=TRUE WHERE id=? AND user_id=?',
      [id(req.params.id), req.user.id])).affectedRows);
    ok(res, null);
  });

  app.get('/api/statistics/overview', librarian, async (req, res) => {
    ok(res, await one(pool, `SELECT
      (SELECT COUNT(*) FROM books WHERE status='active') AS titles,
      (SELECT CAST(COALESCE(SUM(total_copies),0) AS UNSIGNED) FROM books) AS copies,
      (SELECT COUNT(*) FROM borrow_records WHERE status='active') AS borrowed,
      (SELECT COUNT(*) FROM users WHERE role='reader') AS readers,
      (SELECT COUNT(*) FROM borrow_requests WHERE status='pending')+
      (SELECT COUNT(*) FROM renewal_requests WHERE status='pending') AS pending,
      (SELECT COUNT(*) FROM borrow_records WHERE status='active' AND due_at<UTC_TIMESTAMP()) AS overdue`));
  });
  app.get('/api/statistics/borrow-by-month', librarian, async (req, res) => {
    ok(res, await query(pool, `WITH RECURSIVE months AS (
      SELECT CAST(DATE_FORMAT(UTC_DATE(),'%Y-%m-01') AS DATE) - INTERVAL 11 MONTH AS month_start
      UNION ALL SELECT month_start + INTERVAL 1 MONTH FROM months
      WHERE month_start < CAST(DATE_FORMAT(UTC_DATE(),'%Y-%m-01') AS DATE)
    ) SELECT DATE_FORMAT(m.month_start,'%Y-%m') AS month,COUNT(r.id) AS total
      FROM months m LEFT JOIN borrow_records r
        ON r.borrowed_at>=m.month_start AND r.borrowed_at<m.month_start+INTERVAL 1 MONTH
      GROUP BY m.month_start ORDER BY m.month_start`));
  });
  app.get('/api/statistics/books-by-category', librarian, async (req, res) => {
    ok(res, await query(pool, `SELECT c.name,COUNT(b.id) AS total FROM categories c
      LEFT JOIN books b ON b.category_id=c.id AND b.status='active' GROUP BY c.id,c.name ORDER BY c.name`));
  });
  app.get('/api/statistics/popular-books', librarian, async (req, res) => {
    ok(res, await query(pool, `SELECT b.id,b.title,COUNT(r.id) AS total FROM borrow_records r
      JOIN books b ON b.id=r.book_id GROUP BY b.id,b.title ORDER BY total DESC,b.title,b.id LIMIT 5`));
  });
}
