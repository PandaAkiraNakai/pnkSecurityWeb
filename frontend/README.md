# PNKSecurity · Frontend (React + TypeScript)

Carta digital del restaurante (`/?id=N`), inicio de sesión y comentarios, construida con Vite.

```bash
npm ci          # instala exactamente lo de package-lock.json
npm run dev     # http://localhost:5173 (el proxy envía /api a http://localhost:3000)
npm test        # pruebas con Vitest (tests/)
npm run build   # genera dist/, lo que publica Jenkins en Nginx
```

- La sesión viaja en una cookie HttpOnly que fija la API: React no lee ni guarda tokens.
- Los cambios (POST, PUT, DELETE) se envían siempre como JSON.
- `src/validacion.ts` valida en el navegador solo para orientar al usuario; la API valida igual.
- No hay secretos en el frontend: todo lo que se construye llega al navegador.
