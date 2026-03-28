import { prisma } from "../prisma";
import { env } from "../env";

/** Generate a fake Transak-style order ID */
function generateOrderId(): string {
  return `TRX-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

/**
 * Create a mock on-ramp order and return its ID + widget URL.
 * In production this would call the Transak API.
 */
export async function createOnRampOrder(input: {
  transactionId: string;
  fiatCurrency: string;
  fiatAmount: number;
  cryptoAmount: number;
  walletAddress: string;
}): Promise<{ orderId: string; widgetUrl: string }> {
  const externalOrderId = generateOrderId();

  await prisma.rampOrder.create({
    data: {
      type: "onramp",
      transactionId: input.transactionId,
      externalOrderId,
      status: "CREATED",
      fiatCurrency: input.fiatCurrency,
      fiatAmount: input.fiatAmount,
      cryptoCurrency: "USDC",
      cryptoAmount: input.cryptoAmount,
      walletAddress: input.walletAddress,
    },
  });

  // Widget URL points to the backend's mock HTML page
  const widgetUrl = `/onramp/widget?orderId=${encodeURIComponent(externalOrderId)}&amount=${input.fiatAmount}&currency=${input.fiatCurrency}`;

  return { orderId: externalOrderId, widgetUrl };
}

/**
 * Mark an on-ramp order as completed (called after user clicks "Complete Purchase"
 * in the mock Transak widget).
 */
export async function completeOnRampOrder(externalOrderId: string) {
  const order = await prisma.rampOrder.findUnique({
    where: { externalOrderId },
    include: { transaction: true },
  });

  if (!order) {
    throw new Error(`On-ramp order not found: ${externalOrderId}`);
  }

  if (order.status === "COMPLETED") {
    return order;
  }

  const updated = await prisma.rampOrder.update({
    where: { id: order.id },
    data: { status: "COMPLETED" },
    include: { transaction: true },
  });

  return updated;
}

/**
 * Serve the mock Transak widget HTML.
 * This is a self-contained page that shows the purchase amount
 * and fires a JS bridge message when "Complete Purchase" is tapped.
 */
export function renderWidgetHtml(orderId: string, amount: string, currency: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Buy USDC — Mock Transak</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0f0f23 0%, #1a1a3e 100%);
      color: #fff;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .card {
      background: rgba(255,255,255,0.06);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 20px;
      padding: 40px 32px;
      max-width: 380px;
      width: 90%;
      text-align: center;
      backdrop-filter: blur(12px);
    }
    .badge {
      display: inline-block;
      background: rgba(0,200,83,0.15);
      color: #00c853;
      font-size: 12px;
      font-weight: 600;
      padding: 4px 12px;
      border-radius: 20px;
      margin-bottom: 20px;
      letter-spacing: 0.5px;
    }
    h1 { font-size: 22px; margin-bottom: 8px; }
    .amount {
      font-size: 42px;
      font-weight: 700;
      margin: 16px 0 4px;
      background: linear-gradient(90deg, #818cf8, #c084fc);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .sub { color: rgba(255,255,255,0.5); font-size: 14px; margin-bottom: 28px; }
    .details {
      background: rgba(255,255,255,0.04);
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 28px;
      text-align: left;
      font-size: 14px;
      color: rgba(255,255,255,0.7);
    }
    .details .row { display: flex; justify-content: space-between; padding: 6px 0; }
    .details .val { color: #fff; font-weight: 500; }
    button {
      width: 100%;
      padding: 16px;
      border: none;
      border-radius: 14px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      background: linear-gradient(135deg, #818cf8, #6366f1);
      color: #fff;
      transition: transform 0.1s, box-shadow 0.2s;
    }
    button:active { transform: scale(0.97); }
    button:hover { box-shadow: 0 4px 24px rgba(99,102,241,0.4); }
    button:disabled { opacity: 0.5; cursor: not-allowed; }
    .footer { margin-top: 20px; font-size: 12px; color: rgba(255,255,255,0.3); }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">TESTNET · MOCK</div>
    <h1>Buy USDC</h1>
    <div class="amount">${currency} ${amount}</div>
    <div class="sub">≈ ${amount} USDC on Polygon Amoy</div>
    <div class="details">
      <div class="row"><span>Network</span><span class="val">Polygon Amoy</span></div>
      <div class="row"><span>Token</span><span class="val">USDC (Mock)</span></div>
      <div class="row"><span>Fee</span><span class="val">$0.00</span></div>
      <div class="row"><span>Order ID</span><span class="val" style="font-size:11px">${orderId.slice(0, 16)}…</span></div>
    </div>
    <button id="buyBtn" onclick="completePurchase()">Complete Purchase</button>
    <div class="footer">This is a mock widget for demo purposes.</div>
  </div>
  <script>
    function completePurchase() {
      const btn = document.getElementById('buyBtn');
      btn.disabled = true;
      btn.textContent = 'Processing…';
      // Notify Flutter via JS channel or postMessage
      try {
        if (window.TransakBridge) {
          window.TransakBridge.postMessage(JSON.stringify({
            event: 'TRANSAK_ORDER_SUCCESSFUL',
            orderId: '${orderId}'
          }));
        }
      } catch(e) {}
      // Also fire window.postMessage for webview_flutter
      window.postMessage(JSON.stringify({
        event: 'TRANSAK_ORDER_SUCCESSFUL',
        orderId: '${orderId}'
      }), '*');
    }
  </script>
</body>
</html>`;
}
