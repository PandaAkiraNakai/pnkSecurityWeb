import { crearApp } from './app.js';
import { leerConfig } from './config.js';
import { RepoPg } from './repo-pg.js';

const cfg = leerConfig();
const repo = RepoPg.desdeUrl(cfg.databaseUrl);
const app = crearApp(repo, cfg);
app.listen(cfg.port, cfg.host, () => console.log(`API PNKSecurity ${cfg.version} escuchando en ${cfg.host}:${cfg.port}`));
