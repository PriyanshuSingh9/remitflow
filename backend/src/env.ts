import "dotenv/config";

const DEFAULT_PORT = 8787;
const isProduction = process.env.NODE_ENV === "production";

function read(name: string): string | undefined {
  const value = process.env[name];
  return value && value.trim().length > 0 ? value : undefined;
}

function requireInProduction(name: string, fallback?: string): string {
  const value = read(name);
  if (value) {
    return value;
  }
  if (isProduction) {
    throw new Error(`${name} is required in production.`);
  }
  if (fallback === undefined) {
    throw new Error(`${name} is required.`);
  }
  return fallback;
}

export const env = {
  port: Number(read("PORT") ?? DEFAULT_PORT),
  enableDemoBootstrap: (read("ENABLE_DEMO_BOOTSTRAP") ?? "true").toLowerCase() !== "false",
  enableBlockchain: (read("ENABLE_BLOCKCHAIN") ?? "true").toLowerCase() !== "false",
  enableDemoAdmin: (read("ENABLE_DEMO_ADMIN") ?? "false").toLowerCase() === "true",
  googleClientId: requireInProduction(
    "GOOGLE_CLIENT_ID",
    "612184936512-j4tl40a3lmd793k0cirue0t2lca8660k.apps.googleusercontent.com"
  ),
  jwtSecret: requireInProduction("JWT_SECRET", "super_secret_dev_key_for_remitflow"),
  corsOrigin: requireInProduction("CORS_ORIGIN", "*"),

  // ─── Blockchain ──────────────────────────────────────────────────
  rpcUrl: read("RPC_URL") ?? read("POLYGON_AMOY_RPC_URL") ?? "http://127.0.0.1:8545",
  chainId: Number(read("CHAIN_ID") ?? "31337"),
  escrowContractAddress: read("ESCROW_CONTRACT_ADDRESS") ?? read("CONTRACT_ADDRESS") ?? "",
  operatorPrivateKey: read("OPERATOR_PRIVATE_KEY") ?? "",
  usdcAddress: read("USDC_ADDRESS") ?? "",

  // ─── Mock Ramps ──────────────────────────────────────────────────
  mockRampDelayMs: Number(read("MOCK_RAMP_DELAY_MS") ?? "3000"),
};
