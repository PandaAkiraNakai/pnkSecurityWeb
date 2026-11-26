import { useEffect, useState } from 'react';
import { api, ErrorApi, mensajeDeError, type Restaurante, type Usuario } from './api';
import { Aviso } from './components/Aviso';
import { CartaRestaurante } from './components/CartaRestaurante';
import { Comentarios } from './components/Comentarios';
import { Sesion } from './components/Sesion';

// El restaurante se elige con ?id= como en la versión PHP; solo se aceptan enteros positivos
function idDesdeUrl(): number {
  const valor = new URLSearchParams(window.location.search).get('id');
  return valor && /^[1-9]\d{0,8}$/.test(valor) ? Number(valor) : 1;
}

export default function App() {
  const [idRestaurante] = useState(idDesdeUrl);
  const [usuario, setUsuario] = useState<Usuario | null>(null);
  const [restaurante, setRestaurante] = useState<Restaurante | null>(null);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .yo()
      .then(setUsuario)
      .catch((e: unknown) => {
        // 401 = sin sesión, es lo normal al entrar
        if (!(e instanceof ErrorApi && e.status === 401)) setError(mensajeDeError(e));
      });
  }, []);

  // idRestaurante no cambia durante la visita: cargando parte en true y solo se apaga aquí
  useEffect(() => {
    api
      .restaurante(idRestaurante)
      .then((r) => {
        setRestaurante(r);
        document.title = `${r.nombre} · PNKSecurity`;
      })
      .catch((e: unknown) => setError(mensajeDeError(e)))
      .finally(() => setCargando(false));
  }, [idRestaurante]);

  return (
    <>
      <header className="cabecera">
        <div className="contenedor cabecera-contenido">
          <a className="marca" href={`/?id=${idRestaurante}`}>
            <img src="/img/logo.png" alt="" className="marca-logo" />
            <span>{restaurante?.nombre ?? 'PNKSecurity'}</span>
          </a>
          <Sesion usuario={usuario} onCambio={setUsuario} />
        </div>
      </header>

      <main className="contenedor">
        {error && (
          <Aviso tipo="error" onCerrar={() => setError(null)}>
            {error}
          </Aviso>
        )}
        {cargando && <p className="vacio">Cargando la carta…</p>}
        {restaurante && (
          <div className="columnas">
            <CartaRestaurante restaurante={restaurante} />
            <Comentarios idRestaurante={restaurante.id} usuario={usuario} onSesionVencida={() => setUsuario(null)} />
          </div>
        )}
      </main>

      <footer className="pie contenedor">
        <p>PNKSecurity · Carta digital · Desarrollo Seguro CI3064</p>
        <p className="pie-creditos">
          Fotos: «Spinatsuppe mit Croutons» de eat.de (
          <a href="https://creativecommons.org/licenses/by-sa/2.0/" rel="noopener noreferrer" target="_blank">CC BY-SA 2.0</a>) y «Restaurant on Stromboli» de
          kuhnmi (<a href="https://creativecommons.org/licenses/by/2.0/" rel="noopener noreferrer" target="_blank">CC BY 2.0</a>), vía
          Wikimedia Commons. Detalle en <a href="/imagenes/CREDITOS.md">CREDITOS.md</a>.
        </p>
      </footer>
    </>
  );
}
