import "dotenv/config";

const DEFAULT_PORT = 8787;

function read(name: string): string | undefined {
  const value = process.env[name];
  return value && value.trim().length > 0 ? value : undefined;
}

export const env = {
  port: Number(read("PORT") ?? DEFAULT_PORT),
  enableDemoBootstrap: (read("ENABLE_DEMO_BOOTSTRAP") ?? "true").toLowerCase() !== "false",
  googleClientId:
    read("GOOGLE_CLIENT_ID") ??
    "612184936512-j4tl40a3lmd793k0cirue0t2lca8660k.apps.googleusercontent.com",
  jwtSecret: read("JWT_SECRET") ?? "super_secret_dev_key_for_remitflow"
};
