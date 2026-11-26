import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { api, mensajeDeError, type Usuario } from '../api';
import { MIN_PASSWORD, validarRegistro } from '../validacion';
import { Aviso } from './Aviso';

interface Props {
  onCreada: (usuario: Usuario) => void;
  onCerrar: () => void;
}

// Ventana para crear una cuenta. La API vuelve a validar todo, guarda solo el hash de la
// contraseña y, si sale bien, deja la sesión iniciada con su cookie HttpOnly.
export function Registro({ onCreada, onCerrar }: Props) {
  const [datos, setDatos] = useState({ nombre: '', email: '', password: '', repetir: '' });
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);
  const primerCampo = useRef<HTMLInputElement>(null);
  const cerrar = useRef(onCerrar);

  useEffect(() => {
    cerrar.current = onCerrar;
  }, [onCerrar]);

  // Al abrir: foco en el primer campo y Escape para cerrar (una sola vez, no en cada tecla)
  useEffect(() => {
    primerCampo.current?.focus();
    const alPresionar = (e: KeyboardEvent) => {
      if (e.key === 'Escape') cerrar.current();
    };
    window.addEventListener('keydown', alPresionar);
    return () => window.removeEventListener('keydown', alPresionar);
  }, []);

  const cambiar = (campo: keyof typeof datos) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setDatos((d) => ({ ...d, [campo]: e.target.value }));

  async function crear(evento: React.FormEvent) {
    evento.preventDefault();
    evento.stopPropagation();
    setError(null);
    const problema = validarRegistro(datos);
    if (problema) {
      setError(problema);
      return;
    }
    setEnviando(true);
    try {
      const u = await api.registro({ nombre: datos.nombre.trim(), email: datos.email.trim(), password: datos.password });
      onCreada(u);
    } catch (e) {
      setError(mensajeDeError(e));
    } finally {
      setEnviando(false);
    }
  }

  // Portal a <body>: la ventana no queda dentro del formulario de login (formularios anidados)
  return createPortal(
    <div className="modal-fondo" onMouseDown={(e) => e.target === e.currentTarget && onCerrar()}>
      <div className="modal" role="dialog" aria-modal="true" aria-labelledby="registro-titulo">
        <h2 id="registro-titulo">Crear cuenta</h2>
        <p className="modal-ayuda">Con tu cuenta puedes comentar en la carta de cada restaurante.</p>
        <form className="registro-form" onSubmit={crear} noValidate>
          <label>
            <span>Nombre</span>
            <input ref={primerCampo} autoComplete="name" value={datos.nombre} onChange={cambiar('nombre')} maxLength={60} required />
          </label>
          <label>
            <span>Correo</span>
            <input type="email" autoComplete="email" value={datos.email} onChange={cambiar('email')} maxLength={254} required />
          </label>
          <label>
            <span>Contraseña</span>
            <input type="password" autoComplete="new-password" value={datos.password} onChange={cambiar('password')} maxLength={72} required />
            <small>Mínimo {MIN_PASSWORD} caracteres; no uses tu correo.</small>
          </label>
          <label>
            <span>Repite la contraseña</span>
            <input type="password" autoComplete="new-password" value={datos.repetir} onChange={cambiar('repetir')} maxLength={72} required />
          </label>
          {error && (
            <Aviso tipo="error" onCerrar={() => setError(null)}>
              {error}
            </Aviso>
          )}
          <div className="modal-acciones">
            <button type="button" className="boton boton-secundario" onClick={onCerrar} disabled={enviando}>
              Cancelar
            </button>
            <button type="submit" className="boton" disabled={enviando}>
              {enviando ? 'Creando…' : 'Crear cuenta'}
            </button>
          </div>
        </form>
      </div>
    </div>,
    document.body,
  );
}
