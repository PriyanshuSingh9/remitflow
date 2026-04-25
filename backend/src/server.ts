import { createServer } from "node:http";
import type { IncomingMessage, ServerResponse } from "node:http";
import { OAuth2Client } from "google-auth-library";
import jwt from "jsonwebtoken";
import {
  completeOnRamp,
  createTransfer,
  getCurrentUserByGoogleSubject,
  getDashboard,
  getReceiverDashboard,
  getTransferDetail,
  searchRecipients,
  syncSessionFromGoogleIdentity
} from "./app-service";
import { renderWidgetHtml } from "./ramp/mock-transak";
import { startEscrowPoller } from "./ramp/blockchain";
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
    "Access-Control-Allow-Origin": env.corsOrigin,
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

  if (request.method === "GET" && url.pathname === "/me/receiver-dashboard") {
    const session = getCurrentSession(request);
    const currentUser = await getCurrentUserByGoogleSubject(session.subject);
    const dashboard = await getReceiverDashboard(currentUser.id);
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

  // ─── On-Ramp: Mock Widget HTML ─────────────────────────────────
  if (request.method === "GET" && url.pathname === "/onramp/widget") {
    const orderId = url.searchParams.get("orderId") ?? "";
    const amount = url.searchParams.get("amount") ?? "0";
    const currency = url.searchParams.get("currency") ?? "USD";
    const html = renderWidgetHtml(orderId, amount, currency);
    response.writeHead(200, {
      "Content-Type": "text/html; charset=utf-8",
      "Access-Control-Allow-Origin": env.corsOrigin
    });
    response.end(html);
    return;
  }

  // ─── On-Ramp: Complete Purchase ────────────────────────────────
  const onRampCompleteMatch = url.pathname.match(/^\/onramp\/complete\/(.+)$/);
  if (request.method === "POST" && onRampCompleteMatch) {
    const session = getCurrentSession(request);
    await getCurrentUserByGoogleSubject(session.subject);
    const orderId = decodeURIComponent(onRampCompleteMatch[1]);
    const result = await completeOnRamp(orderId);
    sendJson(response, 200, result);
    return;
  }

  // ─── Transfer Detail / Status Polling ──────────────────────────
  const transferDetailMatch = url.pathname.match(/^\/transfers\/([0-9a-f-]+)$/i);
  if (request.method === "GET" && transferDetailMatch) {
    const session = getCurrentSession(request);
    const currentUser = await getCurrentUserByGoogleSubject(session.subject);
    const transferId = transferDetailMatch[1];
    const detail = await getTransferDetail(transferId, currentUser.id);
    sendJson(response, 200, detail);
    return;
  }

  // ─── Demo: Force Release (safety net for live demo) ────────────
  if (request.method === "POST" && url.pathname === "/demo/force-release") {
    if (!env.enableDemoAdmin) {
      throw new HttpError("Demo admin routes are disabled.", 404);
    }
    getCurrentSession(request);

    const body = (await readBody(request)) as { escrowId?: number; transactionId?: string };

    if (body.transactionId) {
      // Look up escrowId from DB
      const tx = await (await import("./prisma")).prisma.transaction.findUnique({
        where: { id: body.transactionId },
      });
      if (!tx || tx.escrowId == null) {
        throw new HttpError("Transaction not found or no escrowId.", 404);
      }
      body.escrowId = tx.escrowId;
    }

    if (body.escrowId == null) {
      throw new HttpError("escrowId or transactionId is required.", 400);
    }

    const { releaseEscrow, confirmReadyForFunding } = await import("./ramp/blockchain");

    // Try confirm first (may fail if already confirmed — that's OK)
    try { await confirmReadyForFunding(body.escrowId); } catch {}

    const txHash = await releaseEscrow(body.escrowId);

    // Update DB status
    if (body.transactionId) {
      await (await import("./prisma")).prisma.transaction.update({
        where: { id: body.transactionId },
        data: {
          status: "completed",
          escrowState: "Released",
          releaseTxHash: txHash,
          completedAt: new Date(),
        },
      });
    }

    sendJson(response, 200, { ok: true, escrowId: body.escrowId, txHash });
    return;
  }

  // ─── Demo: Admin Panel HTML ────────────────────────────────────
  if (request.method === "GET" && url.pathname === "/demo/admin") {
    if (!env.enableDemoAdmin) {
      throw new HttpError("Demo admin routes are disabled.", 404);
    }
    getCurrentSession(request);

    const html = renderDemoAdminHtml();
    response.writeHead(200, {
      "Content-Type": "text/html; charset=utf-8",
      "Access-Control-Allow-Origin": env.corsOrigin,
    });
    response.end(html);
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

function renderDemoAdminHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>RemitFlow — Demo Admin</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0f0f23; color: #e0e0e0;
      min-height: 100vh; display: flex; align-items: center; justify-content: center;
    }
    .card {
      background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1);
      border-radius: 16px; padding: 32px; max-width: 420px; width: 90%;
    }
    h1 { font-size: 20px; margin-bottom: 4px; color: #fff; }
    .sub { color: rgba(255,255,255,0.4); font-size: 13px; margin-bottom: 24px; }
    label { display: block; font-size: 13px; color: rgba(255,255,255,0.6); margin-bottom: 6px; }
    input {
      width: 100%; padding: 12px; border: 1px solid rgba(255,255,255,0.15);
      border-radius: 10px; background: rgba(255,255,255,0.05); color: #fff;
      font-size: 14px; margin-bottom: 16px; outline: none;
    }
    input:focus { border-color: #818cf8; }
    button {
      width: 100%; padding: 14px; border: none; border-radius: 12px;
      font-size: 15px; font-weight: 600; cursor: pointer;
      background: linear-gradient(135deg, #ef4444, #dc2626); color: #fff;
      transition: transform 0.1s;
    }
    button:active { transform: scale(0.97); }
    button:disabled { opacity: 0.5; cursor: not-allowed; }
    .result {
      margin-top: 16px; padding: 12px; border-radius: 10px;
      background: rgba(255,255,255,0.04); font-size: 13px;
      font-family: monospace; white-space: pre-wrap; display: none;
    }
    .result.ok { border-left: 3px solid #22c55e; display: block; }
    .result.err { border-left: 3px solid #ef4444; display: block; color: #fca5a5; }
  </style>
</head>
<body>
  <div class="card">
    <h1>⚡ Demo Admin</h1>
    <div class="sub">Force-release a stuck escrow during live demo</div>

    <label>Escrow ID (number)</label>
    <input id="escrowId" type="number" placeholder="0" />

    <label>— or — Transaction ID (UUID)</label>
    <input id="txId" type="text" placeholder="abc123-..." />

    <button id="btn" onclick="forceRelease()">Force Release Escrow</button>
    <div id="result" class="result"></div>
  </div>
  <script>
    async function forceRelease() {
      const btn = document.getElementById('btn');
      const res = document.getElementById('result');
      const escrowId = document.getElementById('escrowId').value;
      const txId = document.getElementById('txId').value;
      btn.disabled = true; btn.textContent = 'Releasing…';
      res.className = 'result';
      try {
        const body = {};
        if (txId) body.transactionId = txId;
        else if (escrowId !== '') body.escrowId = parseInt(escrowId);
        const r = await fetch('/demo/force-release', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body)
        });
        const data = await r.json();
        if (r.ok) {
          res.className = 'result ok';
          res.textContent = '✓ Released\\nTx: ' + data.txHash;
        } else {
          res.className = 'result err';
          res.textContent = '✗ ' + (data.error || JSON.stringify(data));
        }
      } catch(e) {
        res.className = 'result err';
        res.textContent = '✗ ' + e.message;
      }
      btn.disabled = false; btn.textContent = 'Force Release Escrow';
    }
  </script>
</body>
</html>`;
}

if (env.enableBlockchain) {
  startEscrowPoller().catch((err) =>
    console.warn("[server] Could not start escrow poller:", err)
  );
} else {
  console.log("[server] Blockchain disabled. Set ENABLE_BLOCKCHAIN=true to connect.");
}

server.listen(env.port, "0.0.0.0", () => {
  console.log(`RemitFlow backend listening on http://localhost:${env.port}`);
});
