import 'dotenv/config';
import { createBootstrapAdmin } from '../src/app.js';
import { openDatabase } from '../src/database.js';

const [email, password] = process.argv.slice(2);
const db = openDatabase();

try {
  const id = await createBootstrapAdmin(db, email, password);
  console.log(`Created administrator ${email} (${id}).`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  db.close();
}