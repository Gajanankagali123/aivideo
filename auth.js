window.authApi = {
  register: (name, email, password) => window.api.post('/auth/register', { name, email, password }),
  login: (email, password) => window.api.post('/auth/login', { email, password }),
  logout: () => window.api.post('/auth/logout'),
  me: () => window.api.get('/auth/me'),
  forgotPassword: (email) => window.api.post('/auth/forgot-password', { email }),
  resetPassword: (token, password) => window.api.post('/auth/reset-password', { token, password }),
  updateProfile: (fields) => window.api.patch('/users/me', fields),
  changePassword: (currentPassword, newPassword) => window.api.patch('/users/me/password', { currentPassword, newPassword }),
  updateSettings: (fields) => window.api.patch('/users/me/settings', fields),
  deleteAccount: () => window.api.del('/users/me'),
};
