import "dotenv/config";

const DEFAULT_PORT = 8787;

function read(name: string): string | undefined {
  const value = process.env[name];
  return value && value.trim().length > 0 ? value : undefined;
}

export const env = {
  port: Number(read("PORT") ?? DEFAULT_PORT),
  enableDemoBootstrap: (read("ENABLE_DEMO_BOOTSTRAP") ?? "true").toLowerCase() !== "false",
  enableBlockchain: (read("ENABLE_BLOCKCHAIN") ?? "true").toLowerCase() !== "false",
  googleClientId:
    read("GOOGLE_CLIENT_ID") ??
    "612184936512-j4tl40a3lmd793k0cirue0t2lca8660k.apps.googleusercontent.com",
  jwtSecret: read("JWT_SECRET") ?? "super_secret_dev_key_for_remitflow",

  // ─── Blockchain ──────────────────────────────────────────────────
  rpcUrl: read("RPC_URL") ?? read("POLYGON_AMOY_RPC_URL") ?? "http://127.0.0.1:8545",
  chainId: Number(read("CHAIN_ID") ?? "31337"),
  escrowContractAddress: read("ESCROW_CONTRACT_ADDRESS") ?? read("CONTRACT_ADDRESS") ?? "",
  operatorPrivateKey: read("OPERATOR_PRIVATE_KEY") ?? "",
  usdcAddress: read("USDC_ADDRESS") ?? "",

  // ─── Mock Ramps ──────────────────────────────────────────────────
  mockRampDelayMs: Number(read("MOCK_RAMP_DELAY_MS") ?? "3000"),
};
