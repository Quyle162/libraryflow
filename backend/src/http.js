export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function requireThat(condition, status, code, message) {
  if (!condition) throw new ApiError(status, code, message);
}

export function found(value) {
  requireThat(value, 404, 'not_found', 'Không tìm thấy dữ liệu.');
  return value;
}

export function invalid(field) {
  throw new ApiError(400, 'validation', 'Dữ liệu nhập không hợp lệ: ' + field + '.');
}

export function string(value, field, max, optional = false) {
  if (optional && value == null) return '';
  if (typeof value !== 'string') invalid(field);
  const clean = value.trim();
  if ((!optional && !clean) || clean.length > max) invalid(field);
  return clean;
}

export function integer(value, field, min = 1, max = 2147483647) {
  if (typeof value === 'string' && /^\d+$/.test(value)) value = Number(value);
  if (!Number.isSafeInteger(value) || value < min || value > max) invalid(field);
  return value;
}

export const id = value => integer(value, 'mã định danh');
export const ok = (res, data, status = 200) => res.status(status).json({ data });

export function errors(error, req, res, next) {
  if (res.headersSent) return next(error);
  if (error instanceof ApiError) {
    return res.status(error.status).json({ error: { code: error.code, message: error.message } });
  }
  const responses = {
    ER_DUP_ENTRY: [409, 'duplicate', 'Dữ liệu đã tồn tại.'],
    ER_ROW_IS_REFERENCED_2: [409, 'referenced', 'Dữ liệu đang được sử dụng.'],
    ER_NO_REFERENCED_ROW_2: [409, 'referenced', 'Dữ liệu liên quan không còn tồn tại.'],
    ER_LOCK_DEADLOCK: [409, 'retry', 'Có thao tác đồng thời. Vui lòng thử lại.'],
    ER_LOCK_WAIT_TIMEOUT: [409, 'retry', 'Có thao tác đồng thời. Vui lòng thử lại.'],
    'entity.parse.failed': [400, 'validation', 'Nội dung JSON không hợp lệ.'],
    'entity.too.large': [413, 'validation', 'Dữ liệu gửi lên quá lớn.'],
  };
  const [status, code, message] = responses[error.code || error.type] ||
    [500, 'server_error', 'Máy chủ gặp lỗi. Vui lòng thử lại sau.'];
  if (status === 500) console.error(error.code || error.name);
  res.status(status).json({ error: { code, message } });
}
