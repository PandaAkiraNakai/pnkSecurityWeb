interface Props {
  tipo?: 'error' | 'info' | 'exito';
  children: React.ReactNode;
  onCerrar?: () => void;
}

export function Aviso({ tipo = 'info', children, onCerrar }: Props) {
  return (
    <div className={`aviso aviso-${tipo}`} role={tipo === 'error' ? 'alert' : 'status'}>
      <span>{children}</span>
      {onCerrar && (
        <button type="button" className="aviso-cerrar" onClick={onCerrar} aria-label="Cerrar aviso">
          ×
        </button>
      )}
    </div>
  );
}
