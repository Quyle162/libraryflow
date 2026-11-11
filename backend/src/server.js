import { createApp } from './app.js';
import { pool } from './db.js';
import { generateReminders } from './reporting.js';

const secret = process.env.JWT_SECRET || '';
if (Buffer.byteLength(secret) < 32) throw new Error('JWT_SECRET cần ít nhất 32 byte.');
await pool.query('SELECT 1');
const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || '127.0.0.1';
const server = createApp(secret).listen(port, host, () => console.log('LibraryFlow đang chạy tại http://' + host + ':' + port));
const remind = () => generateReminders().catch(error => console.error('Không thể tạo thông báo:', error.code || error.name));
void remind();
const timer = setInterval(remind, 15 * 60 * 1000);
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.once(signal, () => {
    clearInterval(timer);
    server.close(() => void pool.end());
  });
}
