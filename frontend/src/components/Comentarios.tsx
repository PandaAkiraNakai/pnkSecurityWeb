import { useCallback, useEffect, useState } from 'react';
import { api, mensajeDeError, type Comentario, type Usuario } from '../api';
import { formatearFecha, MAX_COMENTARIO, validarComentario } from '../validacion';
import { Aviso } from './Aviso';

interface Props {
  idRestaurante: number;
  usuario: Usuario | null;
  onSesionVencida: () => void;
}

export function Comentarios({ idRestaurante, usuario, onSesionVencida }: Props) {
  const [comentarios, setComentarios] = useState<Comentario[]>([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [exito, setExito] = useState<string | null>(null);
  const [texto, setTexto] = useState('');
  const [enviando, setEnviando] = useState(false);
  const [editandoId, setEditandoId] = useState<number | null>(null);
  const [textoEdicion, setTextoEdicion] = useState('');

  const obtener = useCallback(
    () =>
      api
        .comentarios(idRestaurante)
        .then((lista) => {
          setComentarios(lista);
          setError(null);
        })
        .catch((e: unknown) => setError(mensajeDeError(e)))
        .finally(() => setCargando(false)),
    [idRestaurante],
  );

  function cargar() {
    setCargando(true);
    void obtener();
  }

  // Al cambiar la sesión se recarga la lista: el campo "propio" depende de quién consulta
  useEffect(() => {
    void obtener();
  }, [obtener, usuario?.id]);

  function manejarError(e: unknown) {
    setExito(null);
    setError(mensajeDeError(e));
    if (e && typeof e === 'object' && 'status' in e && e.status === 401) onSesionVencida();
  }

  async function publicar(evento: React.FormEvent) {
    evento.preventDefault();
    setExito(null);
    const problema = validarComentario(texto);
    if (problema) {
      setError(problema);
      return;
    }
    setEnviando(true);
    try {
      const nuevo = await api.comentar(idRestaurante, texto.trim());
      setComentarios((lista) => [nuevo, ...lista]);
      setTexto('');
      setError(null);
      setExito('Comentario publicado');
    } catch (e) {
      manejarError(e);
    } finally {
      setEnviando(false);
    }
  }

  async function guardarEdicion(id: number) {
    setExito(null);
    const problema = validarComentario(textoEdicion);
    if (problema) {
      setError(problema);
      return;
    }
    setEnviando(true);
    try {
      const editado = await api.editarComentario(id, textoEdicion.trim());
      setComentarios((lista) => lista.map((c) => (c.id === id ? editado : c)));
      setEditandoId(null);
      setError(null);
      setExito('Comentario actualizado');
    } catch (e) {
      manejarError(e);
    } finally {
      setEnviando(false);
    }
  }

  async function eliminar(id: number) {
    if (!window.confirm('¿Eliminar este comentario?')) return;
    setExito(null);
    setEnviando(true);
    try {
      await api.borrarComentario(id);
      setComentarios((lista) => lista.filter((c) => c.id !== id));
      setError(null);
      setExito('Comentario eliminado');
    } catch (e) {
      manejarError(e);
    } finally {
      setEnviando(false);
    }
  }

  const largo = texto.trim().length;

  return (
    <section className="tarjeta">
      <div className="titulo-con-accion">
        <h2 className="titulo-seccion">Comentarios</h2>
        <button type="button" className="boton boton-secundario boton-chico" onClick={cargar} disabled={cargando}>
          {cargando ? 'Cargando…' : 'Actualizar'}
        </button>
      </div>

      {error && (
        <Aviso tipo="error" onCerrar={() => setError(null)}>
          {error}
        </Aviso>
      )}
      {exito && (
        <Aviso tipo="exito" onCerrar={() => setExito(null)}>
          {exito}
        </Aviso>
      )}

      {usuario ? (
        <form className="comentario-form" onSubmit={publicar} noValidate>
          <label htmlFor="nuevo-comentario">Deja tu comentario</label>
          <textarea
            id="nuevo-comentario"
            value={texto}
            onChange={(e) => setTexto(e.target.value)}
            rows={3}
            placeholder="¿Qué te pareció?"
          />
          <div className="comentario-form-pie">
            <span className={largo > MAX_COMENTARIO ? 'contador contador-excedido' : 'contador'}>
              {largo}/{MAX_COMENTARIO}
            </span>
            <button type="submit" className="boton" disabled={enviando}>
              {enviando ? 'Publicando…' : 'Publicar'}
            </button>
          </div>
        </form>
      ) : (
        <Aviso tipo="info">Inicia sesión para comentar.</Aviso>
      )}

      {cargando && comentarios.length === 0 ? (
        <p className="vacio">Cargando comentarios…</p>
      ) : comentarios.length === 0 ? (
        <p className="vacio">Todavía no hay comentarios. ¡Sé el primero!</p>
      ) : (
        <ul className="comentarios">
          {comentarios.map((c) => (
            <li key={c.id} className={c.propio ? 'comentario comentario-propio' : 'comentario'}>
              <div className="comentario-cabecera">
                <strong>{c.autor}</strong>
                <time dateTime={c.creado}>{formatearFecha(c.creado)}</time>
              </div>
              {editandoId === c.id ? (
                <div className="comentario-edicion">
                  <textarea value={textoEdicion} onChange={(e) => setTextoEdicion(e.target.value)} rows={3} aria-label="Editar comentario" />
                  <div className="comentario-form-pie">
                    <span className={textoEdicion.trim().length > MAX_COMENTARIO ? 'contador contador-excedido' : 'contador'}>
                      {textoEdicion.trim().length}/{MAX_COMENTARIO}
                    </span>
                    <div className="acciones">
                      <button type="button" className="boton boton-secundario boton-chico" onClick={() => setEditandoId(null)} disabled={enviando}>
                        Cancelar
                      </button>
                      <button type="button" className="boton boton-chico" onClick={() => void guardarEdicion(c.id)} disabled={enviando}>
                        Guardar
                      </button>
                    </div>
                  </div>
                </div>
              ) : (
                <p className="comentario-texto">{c.texto}</p>
              )}
              {c.propio && usuario && editandoId !== c.id && (
                <div className="acciones">
                  <button
                    type="button"
                    className="boton boton-secundario boton-chico"
                    onClick={() => {
                      setEditandoId(c.id);
                      setTextoEdicion(c.texto);
                    }}
                    disabled={enviando}
                  >
                    Editar
                  </button>
                  <button type="button" className="boton boton-peligro boton-chico" onClick={() => void eliminar(c.id)} disabled={enviando}>
                    Eliminar
                  </button>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
