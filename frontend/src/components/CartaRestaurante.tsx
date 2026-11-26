import type { Restaurante } from '../api';
import { formatearPrecio } from '../validacion';
import { Imagen } from './Imagen';

export function CartaRestaurante({ restaurante }: { restaurante: Restaurante }) {
  const { id } = restaurante;
  const conItems = restaurante.cartas.filter((c) => c.categorias.some((cat) => cat.items.length > 0));

  return (
    <section className="tarjeta">
      <div className="restaurante">
        <Imagen idRestaurante={id} foto={restaurante.foto} alt={restaurante.nombre} className="restaurante-foto" respaldo="/img/logo.png" />
        <div>
          <h2>{restaurante.nombre}</h2>
          <ul className="restaurante-datos">
            {restaurante.direccion && <li>📍 {restaurante.direccion}</li>}
            {restaurante.fono && <li>📞 {restaurante.fono}</li>}
            {restaurante.email && <li>✉️ {restaurante.email}</li>}
          </ul>
        </div>
      </div>

      <h2 className="titulo-seccion">Carta</h2>
      {conItems.length === 0 && <p className="vacio">Este restaurante todavía no tiene productos en su carta.</p>}
      {conItems.map((carta) => (
        <div key={carta.id} className="carta">
          <h3>{carta.nombre}</h3>
          {carta.categorias
            .filter((cat) => cat.items.length > 0)
            .map((cat) => (
              <div key={cat.id} className="categoria">
                <h4>{cat.nombre}</h4>
                <ul className="items">
                  {cat.items.map((item) => (
                    <li key={item.id} className={item.destacado ? 'item item-destacado' : 'item'}>
                      <Imagen idRestaurante={id} foto={item.foto} alt={item.nombre} className="item-foto" />
                      <div className="item-cuerpo">
                        <div className="item-cabecera">
                          <span className="item-nombre">
                            {item.nombre}
                            {item.destacado && <span className="etiqueta">Destacado</span>}
                          </span>
                          {item.precio != null && <span className="item-precio">{formatearPrecio(item.precio)}</span>}
                        </div>
                        {item.descripcion && <p className="item-descripcion">{item.descripcion}</p>}
                        {item.observaciones && <p className="item-observaciones">{item.observaciones}</p>}
                        {item.tiempo && <p className="item-tiempo">⏱ {item.tiempo}</p>}
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
        </div>
      ))}
    </section>
  );
}
