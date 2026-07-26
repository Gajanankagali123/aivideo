// Base API client. Talks to the real backend at API_BASE, always sending cookies.
const API_BASE = window.AMS_API_URL || 'http://localhost:4000/api';

class ApiClientError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details || [];
  }
}

async function request(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    credentials: 'include',
    headers: options.body instanceof FormData ? {} : { 'Content-Type': 'application/json' },
    ...options,
  });

  let json;
  try {
    json = await res.json();
  } catch {
    throw new ApiClientError(res.status, 'PARSE_ERROR', 'The server returned an unexpected response.');
  }

  if (!json.success) {
    // Transparent silent refresh-and-retry once on 401, mirroring the access/refresh cookie design.
    if (res.status === 401 && !options._retried && path !== '/auth/refresh' && path !== '/auth/login') {
      const refreshed = await fetch(`${API_BASE}/auth/refresh`, { method: 'POST', credentials: 'include' }).then((r) => r.json()).catch(() => null);
      if (refreshed && refreshed.success) {
        return request(path, { ...options, _retried: true });
      }
    }
    throw new ApiClientError(res.status, json.error?.code, json.error?.message || 'Something went wrong.', json.error?.details);
  }
  return json.data;
}

window.api = {
  get: (path) => request(path, { method: 'GET' }),
  post: (path, body) => request(path, { method: 'POST', body: body instanceof FormData ? body : JSON.stringify(body || {}) }),
  patch: (path, body) => request(path, { method: 'PATCH', body: JSON.stringify(body || {}) }),
  del: (path) => request(path, { method: 'DELETE' }),
  postForm: (path, formData) => request(path, { method: 'POST', body: formData }),
  ApiClientError,
};
