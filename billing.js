window.billingApi = {
  subscription: () => window.api.get('/billing/subscription'),
  checkout: (planId) => window.api.post('/billing/checkout', { planId }),
  cancel: () => window.api.post('/billing/cancel'),
  // Dev-only helper — simulates the payment provider's webhook so the upgrade flow
  // can be exercised end-to-end without a live payment account. See routes/billing.ts.
  devSimulatePayment: (paymentId) => window.api.post(`/billing/dev-simulate-payment/${paymentId}`),
};

window.notificationsApi = {
  list: () => window.api.get('/notifications'),
  markRead: (id) => window.api.post(`/notifications/${id}/read`),
};
