import { useState } from 'react';

interface Props {
  idRestaurante: number;
  foto: string | null;
  alt: string;
  className?: string;
  respaldo?: string;
}

// Las fotos llegan de la API como nombre de archivo; viven en /imagenes/cod<id>/.
// Si no existe, se usa la imagen de respaldo y, si tampoco carga, no se muestra nada.
export function Imagen({ idRestaurante, foto, alt, className, respaldo = '/imagenes/producto.jpg' }: Props) {
  const inicial = foto && /^[\w.-]+$/.test(foto) ? `/imagenes/cod${idRestaurante}/${foto}` : respaldo;
  const [src, setSrc] = useState<string | null>(inicial);

  if (!src) return null;
  return (
    <img
      className={className}
      src={src}
      alt={alt}
      loading="lazy"
      onError={() => setSrc(src === respaldo ? null : respaldo)}
    />
  );
}
