// Retire l'écran de chargement au premier rendu de Flutter. Fichier séparé
// plutôt que script inline : la CSP n'autorise que les scripts du site.
window.addEventListener('flutter-first-frame', function () {
  var loading = document.querySelector('.sr-loading');
  if (loading) loading.remove();
});
