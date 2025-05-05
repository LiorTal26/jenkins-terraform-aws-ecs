import express from "express";
import bodyParser from "body-parser";
import mysql from "mysql2/promise";
import {
  SecretsManagerClient,
  GetSecretValueCommand,
} from "@aws-sdk/client-secrets-manager";


const REGION   = "il-central-1";
const SECRETID = "rds!db-777ab260-d218-40d6-8bff-a5f247435ce3";
const DB_HOST  = "database-1.c3mggk2emfx1.il-central-1.rds.amazonaws.com";
const DB_PORT  = 3306;
const DB_NAME  = "liordb";
const TABLE    = "people";
const PORT     = 3000;

async function fetchCreds() {
  const sm = new SecretsManagerClient({ region: REGION });
  const res = await sm.send(new GetSecretValueCommand({ SecretId: SECRETID }));
  return JSON.parse(res.SecretString);             // { username, password }
}

async function openDb() {
  const { username, password } = await fetchCreds();
  return mysql.createConnection({
    host: DB_HOST,
    port: DB_PORT,
    user: username,
    password,
    database: DB_NAME,
  });
}

async function ensureTable() {
  const db = await openDb();
  await db.execute(`
    CREATE TABLE IF NOT EXISTS ${TABLE} (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(255),
      shoes_size DOUBLE
    )`);
  await db.end();
}


const app = express();
app.use(bodyParser.urlencoded({ extended: true }));

await ensureTable();

// GET / → form + list
app.get("/", async (_req, res) => {
  // check DB health
  const dbStatus = await checkDb();
  const healthTxt = dbStatus.ok ? "DB is healthy" : "DB is unhealthy";
  const healthColor = dbStatus.ok ? "green" : "red";

  const db = await openDb();
  const [rows] = await db.query(`SELECT * FROM ${TABLE}`);
  await db.end();

  const htmlRows = rows
    .map(
      r =>
        `<tr><td>${r.id}</td><td>${r.name}</td><td>${r.shoes_size}</td></tr>`
    )
    .join("");

  res.send(`
    <h2>Add Person</h2>
    <form method="POST">
      Name: <input name="name" required><br>
      Shoe size: <input name="shoes_size" type="number" step="0.1" required><br>
      <button type="submit">Submit</button>
    </form>
        <h2> from the data base: ${DB_NAME}</h2>
    <h4 style="color:${healthColor}">DB health: ${healthTxt}</h4>
    <h3>Current rows</h3>
    <h4>from the table: ${TABLE}</h4>
    <table border="1" cellspacing="0" cellpadding="4">
      <tr><th>ID</th><th>Name</th><th>Shoe size</th></tr>
      ${htmlRows}
    </table>
  `);
});

// POST / → insert row
app.post("/", async (req, res) => {
  const { name, shoes_size } = req.body;
  if (!name || !shoes_size) {
    return res.status(400).send("Both fields required");
  }

  const db = await openDb();
  await db.execute(
    `INSERT INTO ${TABLE} (name, shoes_size) VALUES (?, ?)`,
    [name, parseFloat(shoes_size)]
  );
  await db.end();
  res.redirect("/");
});

// db health check
async function checkDb () {
  try {
    const db = await openDb();
    await db.execute("SELECT 1");  
    await db.end();
    return { ok: true };
  } catch (err) {
    console.error("DB health check failed", err);
    return { ok: false, message: err.message };
  }
}

// health route
app.get("/health", async (_req, res) => {
  const dbStatus = await checkDb();
  const overall  = dbStatus.ok ? "healthy" : "unhealthy";
  res.status(dbStatus.ok ? 200 : 503).json({
    status: overall,
    db: dbStatus,
  });
});

// start server
app.listen(PORT, () => {
  console.log(`✅  Server running – open http://localhost:${PORT}`);
});

