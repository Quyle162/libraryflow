import { fileURLToPath } from 'node:url';
import express from 'express';
import cors from 'cors';
import { pool } from './db.js';
import { authRoutes } from './auth.js';
import { catalogRoutes } from './catalog.js';
import { circulationRoutes } from './circulation.js';
import { reportingRoutes } from './reporting.js';
import { ApiError, errors, ok } from './http.js';

export function createApp(secret) {
  const app = express();
  app.disable('x-powered-by');
  const origins = (process.env.CORS_ORIGINS || '').split(',').map(value => value.trim()).filter(Boolean);
  app.use(cors({ origin: origins }));
  app.use(express.json({ limit: '32kb' }));
  app.get('/api/health', async (req, res) => {
    await pool.query('SELECT 1');
    ok(res, { ready: true });
  });
  app.use('/api/covers', express.static(fileURLToPath(new URL('../public/covers', import.meta.url)), {
    fallthrough: true, maxAge: '1d', index: false,
  }));
  authRoutes(app, secret);
  catalogRoutes(app);
  circulationRoutes(app);
  reportingRoutes(app);
  app.use((req, res, next) => next(new ApiError(404, 'not_found', 'Không tìm thấy địa chỉ API.')));
  app.use(errors);
  return app;
}
