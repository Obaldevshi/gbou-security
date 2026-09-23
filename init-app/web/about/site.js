(() => {
  document.getElementById('year').textContent = new Date().getFullYear();
  const contact = window.GBOU_PUBLIC_CONTACT || {};
  const link = document.getElementById('contact-link');
  const missing = document.getElementById('contact-missing');
  let href = '';
  if (contact.email) href = `mailto:${contact.email}?subject=${encodeURIComponent('Демонстрация системы учёта выхода учащихся')}`;
  else if (contact.telegram) href = `https://t.me/${String(contact.telegram).replace(/^@/, '')}`;
  else if (contact.phone) href = `tel:${String(contact.phone).replace(/[^+\d]/g, '')}`;
  if (href) {
    link.href = href;
    link.hidden = false;
    missing.hidden = true;
  }
})();
