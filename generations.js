window.generationsApi = {
  textToVideo: (payload) => window.api.post('/generations/text-to-video', payload),

  imageToVideo: (file, fields) => {
    const fd = new FormData();
    fd.append('image', file);
    Object.entries(fields || {}).forEach(([k, v]) => fd.append(k, v));
    return window.api.postForm('/generations/image-to-video', fd);
  },

  scriptToVideo: (payload) => window.api.post('/generations/script-to-video', payload),
  avatarVideo: (payload) => window.api.post('/generations/avatar-video', payload),
  voiceover: (payload) => window.api.post('/generations/voiceover', payload),

  getJob: (jobId) => window.api.get(`/generations/jobs/${jobId}`),
  cancelJob: (jobId) => window.api.post(`/generations/jobs/${jobId}/cancel`),

  /**
   * Polls a job until it reaches a terminal state, invoking onUpdate on every tick.
   * Returns the final job object. This replaces the old fake setInterval progress bar.
   */
  async pollJob(jobId, onUpdate, { intervalMs = 1200, timeoutMs = 180000 } = {}) {
    const start = Date.now();
    while (true) {
      const job = await window.generationsApi.getJob(jobId);
      onUpdate(job);
      if (['completed', 'failed', 'canceled'].includes(job.status)) return job;
      if (Date.now() - start > timeoutMs) throw new Error('Generation timed out.');
      await new Promise((r) => setTimeout(r, intervalMs));
    }
  },
};

window.assetsApi = {
  list: (type) => window.api.get(`/assets${type ? '?type=' + type : ''}`),
  upload: (file) => {
    const fd = new FormData();
    fd.append('file', file);
    return window.api.postForm('/assets', fd);
  },
  downloadUrl: (id) => window.api.get(`/assets/${id}/download-url`),
  remove: (id) => window.api.del(`/assets/${id}`),
};

window.libraryApi = {
  templates: (category) => window.api.get(`/templates${category && category !== 'All' ? '?category=' + encodeURIComponent(category) : ''}`),
  useTemplate: (id) => window.api.post(`/templates/${id}/use`),
  avatars: () => window.api.get('/avatars'),
  uploadAvatar: (file, name) => {
    const fd = new FormData();
    fd.append('image', file);
    if (name) fd.append('name', name);
    return window.api.postForm('/avatars/custom', fd);
  },
  voices: () => window.api.get('/voices'),
  voicePreview: (id) => window.api.get(`/voices/${id}/preview`),
};

window.creditsApi = {
  balance: () => window.api.get('/credits/balance'),
  transactions: () => window.api.get('/credits/transactions'),
};

window.plansApi = {
  list: () => window.api.get('/plans'),
};
