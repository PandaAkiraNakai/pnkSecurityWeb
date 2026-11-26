import { useState } from 'react';
import { api, mensajeDeError, type Usuario } from '../api';
import { Aviso } from './Aviso';

interface Props {
  usuario: Usuario | null;
  onCambio: (usuario: Usuario | null) => void;
}

export function Sesion({ usuario, onCambio }: Props) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  async function entrar(evento: React.FormEvent) {
    evento.preventDefault();
    setError(null);
    if (!email.trim() || !password) {
      setError('Ingresa tu correo y tu contraseña');
      return;
    }
    setEnviando(true);
    try {
      const u = await api.login(email.trim(), password);
      setPassword('');
      onCambio(u);
    } catch (e) {
      setError(mensajeDeError(e));
    } finally {
      setEnviando(false);
    }
  }

  async function salir() {
    setError(null);
    setEnviando(true);
    try {
      await api.logout();
      onCambio(null);
    } catch (e) {
      setError(mensajeDeError(e));
    } finally {
      setEnviando(false);
    }
  }

  if (usuario) {
    return (
      <div className="sesion">
        <span className="sesion-hola">
          Hola, <strong>{usuario.nombre}</strong>
        </span>
        <button type="button" className="boton boton-secundario" onClick={salir} disabled={enviando}>
          {enviando ? 'Cerrando…' : 'Cerrar sesión'}
        </button>
        {error && <Aviso tipo="error">{error}</Aviso>}
      </div>
    );
  }

  return (
    <form className="sesion sesion-form" onSubmit={entrar} noValidate>
      <label>
        <span>Correo</span>
        <input
          type="email"
          autoComplete="username"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          maxLength={254}
          required
        />
      </label>
      <label>
        <span>Contraseña</span>
        <input
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          maxLength={128}
          required
        />
      </label>
      <button type="submit" className="boton" disabled={enviando}>
        {enviando ? 'Entrando…' : 'Iniciar sesión'}
      </button>
      {error && (
        <Aviso tipo="error" onCerrar={() => setError(null)}>
          {error}
        </Aviso>
      )}
    </form>
  );
}
