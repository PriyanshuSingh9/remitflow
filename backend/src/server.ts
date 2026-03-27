import { createServer } from "node:http";
import type { IncomingMessage, ServerResponse } from "node:http";
import { getFirebaseAuth } from "./firebase-admin";
import {
  createTransfer,
  getCurrentUserByFirebaseUid,
  getDashboard,
  searchRecipients,
  syncSessionFromToken
} from "./app-service";
import { env } from "./env";

type JsonRecord = Record<string, unknown>;

class HttpError extends Error {
  constructor(
    message: string,
    readonly statusCode: number
  ) {
    super(message);
  }
}

function sendJson(response: ServerResponse, statusCode: number, body: JsonRecord) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
  });
  response.end(JSON.stringify(body));
}

async function readBody(request: IncomingMessage) {
  const chunks: Buffer[] = [];
  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }

  if (chunks.length === 0) {
    return {};
  }

  const raw = Buffer.concat(chunks).toString("utf8");
  return raw ? (JSON.parse(raw) as JsonRecord) : {};
}

function getBearerToken(request: IncomingMessage) {
  const header = request.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    throw new HttpError("Missing Authorization bearer token.", 401);
  }

  return header.slice("Bearer ".length).trim();
}

async function getCurrentToken(request: IncomingMessage) {
  try {
    const auth = getFirebaseAuth();
    const token = getBearerToken(request);
    return await auth.verifyIdToken(token);
  } catch {
    throw new HttpError("Invalid or expired Firebase ID token.", 401);
  }
}

async function routeRequest(request: IncomingMessage, response: ServerResponse) {
  if (!request.url || !request.method) {
    throw new HttpError("Unsupported request.", 400);
  }

  if (request.method === "OPTIONS") {
    sendJson(response, 204, {});
    return;
  }

  const url = new URL(request.url, `http://${request.headers.host ?? "localhost"}`);

  if (request.method === "GET" && url.pathname === "/health") {
    sendJson(response, 200, {
      ok: true,
      service: "remitflow-backend"
    });
    return;
  }

  if (request.method === "POST" && url.pathname === "/auth/session") {
    const token = await getCurrentToken(request);
    const body = (await readBody(request)) as {
      walletAddress?: string;
      country?: string;
      phoneNumber?: string;
    };
    const session = await syncSessionFromToken(token, body);
    sendJson(response, 200, session);
    return;
  }

  if (request.method === "GET" && url.pathname === "/me/dashboard") {
    const token = await getCurrentToken(request);
    const currentUser = await getCurrentUserByFirebaseUid(token.uid);
    const dashboard = await getDashboard(currentUser.id);
    sendJson(response, 200, dashboard);
    return;
  }

  if (request.method === "GET" && url.pathname === "/recipients") {
    const token = await getCurrentToken(request);
    const currentUser = await getCurrentUserByFirebaseUid(token.uid);
    const results = await searchRecipients(currentUser.id, url.searchParams.get("q") ?? "");
    sendJson(response, 200, results);
    return;
  }

  if (request.method === "POST" && url.pathname === "/transfers") {
    const token = await getCurrentToken(request);
    const currentUser = await getCurrentUserByFirebaseUid(token.uid);
    const body = (await readBody(request)) as {
      recipientId?: string;
      amountUsd?: number;
    };

    if (!body.recipientId) {
      throw new HttpError("recipientId is required.", 400);
    }

    const transfer = await createTransfer(currentUser.id, {
      recipientId: body.recipientId,
      amountUsd: Number(body.amountUsd)
    });

    sendJson(response, 201, transfer);
    return;
  }

  throw new HttpError(`Route not found: ${request.method} ${url.pathname}`, 404);
}

const server = createServer(async (request, response) => {
  try {
    await routeRequest(request, response);
  } catch (error) {
    if (error instanceof HttpError) {
      sendJson(response, error.statusCode, {
        error: error.message
      });
      return;
    }

    const message = error instanceof Error ? error.message : "Unknown server error.";
    sendJson(response, 500, {
      error: message
    });
  }
});

server.listen(env.port, () => {
  console.log(`RemitFlow backend listening on http://localhost:${env.port}`);
});
