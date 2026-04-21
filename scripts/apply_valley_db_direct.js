#!/usr/bin/env node

/*
 * Applies the Valley PostgreSQL and MongoDB migrations directly through Node
 * drivers. This is a local recovery path for hosts where Docker Desktop exposes
 * the database ports but docker exec, psql, or mongosh are unavailable.
 */

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const runtimeModules = path.resolve(__dirname, "..", "tmp", "db-deploy-runtime", "node_modules");
require.main.paths.unshift(runtimeModules);

const { Client } = require("pg");
const { MongoClient } = require("mongodb");

const ROOT = path.resolve(__dirname, "..");
const MANIFEST_PATH = path.join(ROOT, "database", "migrations.json");
const ENV_EXAMPLE_PATH = path.join(ROOT, ".env.example");
const ENV_PATH = path.join(ROOT, ".env");

function parseEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }
  const values = {};
  for (const rawLine of fs.readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || !line.includes("=")) {
      continue;
    }
    const index = line.indexOf("=");
    const key = line.slice(0, index).trim();
    const value = line.slice(index + 1).trim().replace(/^['"]|['"]$/g, "");
    if (key) {
      values[key] = value;
    }
  }
  return values;
}

function loadEnvDefaults() {
  const defaults = {
    ...parseEnvFile(ENV_EXAMPLE_PATH),
    ...parseEnvFile(ENV_PATH),
  };
  for (const [key, value] of Object.entries(defaults)) {
    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

async function applyPostgres(manifest) {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error("DATABASE_URL nao configurado.");
  }

  const client = new Client({
    connectionString: databaseUrl,
    connectionTimeoutMillis: Number(process.env.VALLEY_DIRECT_CONNECT_TIMEOUT_MS || 10_000),
    query_timeout: Number(process.env.VALLEY_DIRECT_QUERY_TIMEOUT_MS || 120_000),
    statement_timeout: Number(process.env.VALLEY_DIRECT_QUERY_TIMEOUT_MS || 120_000),
  });
  await client.connect();
  try {
    for (const item of manifest.postgres || []) {
      const migrationPath = path.join(ROOT, item.path);
      const sql = fs.readFileSync(migrationPath, "utf8");
      process.stdout.write(`postgres ${item.id}: ${item.path} ... `);
      await client.query(sql);
      process.stdout.write("ok\n");
    }
  } finally {
    await client.end();
  }
}

function buildMongoScriptOps(scriptText, collectionNames) {
  const ops = [];
  const knownCollections = new Set(collectionNames);

  const dbTarget = {
    getCollectionNames() {
      return Array.from(knownCollections);
    },
    createCollection(collectionName, options) {
      ops.push({ type: "createCollection", collectionName, options });
      knownCollections.add(collectionName);
      return { ok: 1 };
    },
    runCommand(command) {
      ops.push({ type: "runCommand", command });
      if (command && command.collMod) {
        knownCollections.add(command.collMod);
      }
      return { ok: 1 };
    },
  };

  const db = new Proxy(dbTarget, {
    get(target, prop) {
      if (prop in target) {
        return target[prop];
      }
      if (typeof prop !== "string") {
        return undefined;
      }
      return {
        createIndex(keys, options) {
          ops.push({ type: "createIndex", collectionName: prop, keys, options });
          return `${prop}_${Object.keys(keys).join("_")}`;
        },
      };
    },
  });

  const context = vm.createContext({
    db,
    print: (...args) => console.log(...args),
  });

  vm.runInContext(scriptText, context, { timeout: 10_000 });
  return ops;
}

async function applyMongo(manifest) {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error("MONGODB_URI nao configurado.");
  }

  const client = new MongoClient(mongoUri, {
    serverSelectionTimeoutMS: Number(process.env.VALLEY_DIRECT_CONNECT_TIMEOUT_MS || 10_000),
    connectTimeoutMS: Number(process.env.VALLEY_DIRECT_CONNECT_TIMEOUT_MS || 10_000),
    socketTimeoutMS: Number(process.env.VALLEY_DIRECT_QUERY_TIMEOUT_MS || 120_000),
  });
  await client.connect();
  try {
    const db = client.db();
    for (const item of manifest.mongodb || []) {
      const scriptPath = path.join(ROOT, item.path);
      const scriptText = fs.readFileSync(scriptPath, "utf8");
      const collectionNames = await db.listCollections({}, { nameOnly: true }).toArray();
      const ops = buildMongoScriptOps(scriptText, collectionNames.map((entry) => entry.name));
      process.stdout.write(`mongodb ${item.id}: ${item.path} ... `);
      for (const op of ops) {
        if (op.type === "createCollection") {
          await db.createCollection(op.collectionName, op.options);
        } else if (op.type === "runCommand") {
          await db.command(op.command);
        } else if (op.type === "createIndex") {
          await db.collection(op.collectionName).createIndex(op.keys, op.options);
        }
      }
      process.stdout.write(`ok (${ops.length} ops)\n`);
    }
  } finally {
    await client.close();
  }
}

async function main() {
  loadEnvDefaults();
  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));

  const target = process.argv[2] || "all";
  if (!["all", "postgres", "mongo"].includes(target)) {
    throw new Error("Uso: node scripts/apply_valley_db_direct.js [all|postgres|mongo]");
  }

  if (target === "all" || target === "postgres") {
    await applyPostgres(manifest);
  }
  if (target === "all" || target === "mongo") {
    await applyMongo(manifest);
  }
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
