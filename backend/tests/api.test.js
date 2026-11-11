import assert from 'node:assert/strict';
import { once } from 'node:events';
import { test } from 'node:test';

test('API xác thực và bảo vệ dữ liệu đầu vào khi chưa đăng nhập', async t => {
  const { createApp } = await import('../src/app.js');
  const server = createApp('test-secret-for-invalid-requests').listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = 'http://127.0.0.1:' + server.address().port + '/api';
  const response = await fetch(base + '/books');
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, 'unauthorized');
  const invalid = await fetch(base + '/auth/login', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{',
  });
  assert.equal(invalid.status, 400);
  assert.equal((await invalid.json()).error.code, 'validation');
});
