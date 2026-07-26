window.projectsApi = {
  list: (params = {}) => {
    const qs = new URLSearchParams(params).toString();
    return window.api.get(`/projects${qs ? '?' + qs : ''}`);
  },
  get: (id) => window.api.get(`/projects/${id}`),
  rename: (id, title) => window.api.patch(`/projects/${id}`, { title }),
  remove: (id) => window.api.del(`/projects/${id}`),
  duplicate: (id) => window.api.post(`/projects/${id}/duplicate`),
  getEditor: (id) => window.api.get(`/projects/${id}/editor`),
  saveEditor: (id, timeline) => window.api.patch(`/projects/${id}/editor`, { timeline }),
  render: (id) => window.api.post(`/projects/${id}/render`),
  exports: (id) => window.api.get(`/projects/${id}/exports`),
};

window.dashboardApi = {
  summary: () => window.api.get('/dashboard/summary'),
};
