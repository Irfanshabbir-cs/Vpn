import 'dotenv/config';
import { createApp } from './app.js';

const port = Number.parseInt(process.env.PORT ?? '8080', 10);
const app = createApp();
const server = app.listen(port, '0.0.0.0', () => {
  console.log(`ShieldVPN API listening on http://localhost:${port}/v1`);
});

function shutdown() {
  server.close(() => {
    app.locals.db.close();
    process.exit(0);
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);