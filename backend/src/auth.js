import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { one, query, pool } from './db.js';
import { requireThat, string, invalid, ok } from './http.js';

export const publicUser = 'id,full_name,student_code,email,username,role,status';
const badLogin = 'Tên đăng nhập hoặc mật khẩu không đúng.';
const expired = 'Phiên đăng nhập đã hết hạn.';
const demoHash = '$2b$10$UxTSd4P5qcy6Uz4aNhUZaeIuCjvwaICHOD/LHs98FX9yrLvjroH82';

function password(value, min) {
  if (typeof value !== 'string' || value.length < min || Buffer.byteLength(value) > 72) {
    invalid('mật khẩu');
  }
  return value;
}

export function librarian(req, res, next) {
  requireThat(req.user.role === 'librarian', 403, 'forbidden', 'Bạn không có quyền thực hiện.');
  next();
}

export function reader(req, res, next) {
  requireThat(req.user.role === 'reader', 403, 'forbidden', 'Chức năng dành cho độc giả.');
  next();
}

export function authRoutes(app, secret) {
  app.post('/api/auth/login', async (req, res) => {
    const login = string(req.body?.login, 'tài khoản', 254);
    const pass = password(req.body?.password, 1);
    const column = login.includes('@') ? 'email' : 'username';
    const user = await one(pool, `SELECT ${publicUser}, password_hash, token_version FROM users WHERE ${column}=?`, [login]);
    const matches = await bcrypt.compare(pass, user?.password_hash || demoHash);
    requireThat(user && matches, 401, 'invalid_credentials', badLogin);
    requireThat(user.status === 'active', 403, 'locked', 'Tài khoản đang bị khóa.');
    const { password_hash, token_version, ...profile } = user;
    const token = jwt.sign({ ver: token_version }, secret, {
      subject: String(user.id), algorithm: 'HS256', expiresIn: '12h', issuer: 'libraryflow',
    });
    ok(res, { token, user: profile });
  });

  app.use('/api', async (req, res, next) => {
    const token = /^Bearer (\S+)$/.exec(req.get('Authorization') || '')?.[1];
    let claims;
    try {
      claims = jwt.verify(token, secret, { algorithms: ['HS256'], issuer: 'libraryflow' });
    } catch {
      requireThat(false, 401, 'unauthorized', expired);
    }
    const user = await one(pool, `SELECT ${publicUser}, token_version FROM users WHERE id=?`, [claims.sub]);
    requireThat(user?.status === 'active' && user.token_version === claims.ver, 401, 'unauthorized', expired);
    const { token_version, ...profile } = user;
    req.user = profile;
    next();
  });

  app.get('/api/auth/me', (req, res) => ok(res, req.user));
  app.put('/api/auth/change-password', async (req, res) => {
    const current = password(req.body?.current_password, 1);
    const replacement = password(req.body?.new_password, 8);
    const { password_hash } = await one(pool, 'SELECT password_hash FROM users WHERE id=?', [req.user.id]);
    requireThat(await bcrypt.compare(current, password_hash), 400, 'wrong_password', 'Mật khẩu hiện tại không đúng.');
    const hash = await bcrypt.hash(replacement, 12);
    const result = await query(pool, 'UPDATE users SET password_hash=?, token_version=token_version+1 WHERE id=? AND BINARY password_hash=?',
      [hash, req.user.id, password_hash]);
    requireThat(result.affectedRows, 409, 'retry', 'Mật khẩu vừa thay đổi. Vui lòng thử lại.');
    ok(res, null);
  });
}
