// Enter in the sign-in form signs in.
document.addEventListener('keydown', function (e) {
  if (e.key !== 'Enter') return;
  var id = e.target && e.target.id;
  if (id === 'welcome-username' || id === 'welcome-password') {
    e.preventDefault();
    // Shiny reads text inputs on change; blur first so the value is sent.
    e.target.blur();
    setTimeout(function () { document.getElementById('welcome-signin').click(); }, 50);
  }
});
