import "dotenv/config";

const DEFAULT_PORT = 8787;

function read(name: string): string | undefined {
  const value = process.env[name];
  return value && value.trim().length > 0 ? value : undefined;
}

export const env = {
  port: Number(read("PORT") ?? DEFAULT_PORT),
  enableDemoBootstrap: (read("ENABLE_DEMO_BOOTSTRAP") ?? "true").toLowerCase() !== "false",
  firebaseProjectId: read("FIREBASE_PROJECT_ID"),
  firebaseClientEmail: read("FIREBASE_CLIENT_EMAIL"),
  firebasePrivateKey: read("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, "\n")
};

export function assertFirebaseEnv() {
  if (!env.firebaseProjectId || !env.firebaseClientEmail || !env.firebasePrivateKey) {
    throw new Error(
      "Missing Firebase admin environment. Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY."
    );
  }
}
