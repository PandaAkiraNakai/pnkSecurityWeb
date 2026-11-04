// Carrito de PNKSecurity.
// ES3: reescrito sin jQuery (se eliminó jQuery 3.2.1, que tenía CVE-2019-11358, CVE-2020-11022 y
// CVE-2020-11023). Usa fetch y el componente Modal de Bootstrap 5. Toda petición lleva el token
// CSRF de la página en la cabecera X-CSRF-Token; sin él, carrito.php responde 403.
(function () {
  'use strict';
  var meta = document.querySelector('meta[name="csrf-token"]');
  var token = meta ? meta.getAttribute('content') : '';

  function enviar(datos) {
    return fetch('carrito.php', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'X-CSRF-Token': token },
      body: new URLSearchParams(datos)
    }).then(function (r) {
      if (!r.ok) { throw new Error('HTTP ' + r.status); }
      return r;
    });
  }

  function fallo() {
    window.alert('No se pudo actualizar el carrito. Recargue la página e intente de nuevo.');
  }

  document.addEventListener('click', function (ev) {
    var agregar = ev.target.closest('a.button');
    var quitar = ev.target.closest('a.elim');
    var vaciar = ev.target.closest('a.limpiar');
    if (agregar) {
      ev.preventDefault();
      enviar({ op: '1', iditems: agregar.id }).then(function () {
        bootstrap.Modal.getOrCreateInstance(document.getElementById('myModal')).show();
      }).catch(fallo);
    } else if (quitar) {
      ev.preventDefault();
      enviar({ op: '2', pos: quitar.id }).then(function () { location.reload(); }).catch(fallo);
    } else if (vaciar) {
      ev.preventDefault();
      enviar({ op: '3' }).then(function () { location.reload(); }).catch(fallo);
    }
  });
})();
