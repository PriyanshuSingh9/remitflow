import { createServer } from "node:http";
import type { IncomingMessage, ServerResponse } from "node:http";
import { OAuth2Client } from "google-auth-library";
import jwt from "jsonwebtoken";
import {
  createTransfer,
  getCurrentUserByGoogleSubject,
  getDashboard,
  searchRecipients,
  syncSessionFromGoogleIdentity
} from "./app-service";
import { env } from "./env";

type JsonRecord = Record<string, unknown>;
type SessionClaims = {
  userId: string;
  subject: string;
  email: string;
};

const googleClient = new OAuth2Client(env.googleClientId);

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

async function verifyGoogleIdentityToken(idToken: string) {
  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: env.googleClientId
    });
    const payload = ticket.getPayload();
    if (!payload?.sub || !payload.email) {
      throw new Error("Invalid Google token payload.");
    }

    return {
      sub: payload.sub,
      email: payload.email,
      name: payload.name ?? null,
      picture: payload.picture ?? null
    };
  } catch {
    throw new HttpError("Invalid or expired Google ID token.", 401);
  }
}

function signSession(user: { id: string; googleSubject: string | null; email: string }) {
  return jwt.sign(
    {
      userId: user.id,
      subject: user.googleSubject,
      email: user.email
    },
    env.jwtSecret,
    { expiresIn: "30d" }
  );
}

function getCurrentSession(request: IncomingMessage): SessionClaims {
  try {
    const token = getBearerToken(request);
    const session = jwt.verify(token, env.jwtSecret) as Partial<SessionClaims>;
    if (!session.userId || !session.subject || !session.email) {
      throw new Error("Invalid session payload.");
    }
    return {
      userId: session.userId,
      subject: session.subject,
      email: session.email
    };
  } catch {
    throw new HttpError("Invalid or expired session token.", 401);
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

  if (request.method === "POST" && url.pathname === "/auth/google") {
    const body = (await readBody(request)) as {
      idToken?: string;
      walletAddress?: string;
      country?: string;
      phoneNumber?: string;
    };
    if (!body.idToken) {
      throw new HttpError("idToken is required.", 400);
    }

    const identity = await verifyGoogleIdentityToken(body.idToken);
    const session = await syncSessionFromGoogleIdentity(identity, body);
    sendJson(response, 200, {
      token: signSession({
        id: session.user.id,
        googleSubject: identity.sub,
        email: session.user.email
      }),
      user: session.user
    });
    return;
  }

  if (request.method === "GET" && url.pathname === "/auth/me") {
    const session = getCurrentSession(request);
    const currentUser = await getCurrentUserByGoogleSubject(session.subject);
    sendJson(response, 200, {
      user: {
        id: currentUser.id,
        email: currentUser.email,
        displayName: currentUser.displayName,
        photoUrl: currentUser.photoUrl,
        phoneNumber: currentUser.phoneNumber,
        walletAddress: currentUser.walletAddress,
        country: currentUser.country,
        availableBalanceUsd: Number(currentUser.availableBalanceUsd.toString()),
        lifetimeSavingsUsd: Number(currentUser.lifetimeSavingsUsd.toString())
      }
    });
    return;
  }

  if (request.method === "GET" && url.pathname === "/me/dashboard") {
    const session = getCurrentSession(request);
    const currentUser = await getCurrentUserByGoogleSubject(session.subject);
    const dashboard = await getDashboard(currentUser.id);
    sendJson(response, 200, dashboard);
    return;
  }

  if (request.method === "GET" && url.pathname === "/recipients") {
    const session = getCurrentSession(request);
    const currentUser = await getCurrentUserByGoogleSubject(session.subject);
    const results = await searchRecipients(currentUser.id, url.searchParams.get("q") ?? "");
    sendJson(response, 200, results);
    return;
  }

  if (request.method === "POST" && url.pathname === "/transfers") {
    const session = getCurrentSession(request);
    const currentUser = await getCurrentUserByGoogleSubject(session.subject);
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

server.listen(env.port, "0.0.0.0", () => {
  console.log(`RemitFlow backend listening on http://localhost:${env.port}`);
});
