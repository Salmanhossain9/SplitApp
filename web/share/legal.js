// Fills in the contact email from config.js so it is written in one place.
(function () {
  var mail = (window.SPLITBIT_CONTACT_EMAIL || '').trim();
  document.querySelectorAll('.contact').forEach(function (el) {
    if (mail) {
      var a = document.createElement('a');
      a.href = 'mailto:' + mail;
      a.textContent = mail;
      el.replaceChildren(a);
    }
  });
})();
