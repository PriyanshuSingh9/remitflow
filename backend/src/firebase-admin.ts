import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { assertFirebaseEnv, env } from "./env";

export function getFirebaseAuth() {
  if (getApps().length === 0) {
    assertFirebaseEnv();

    initializeApp({
      credential: cert({
        projectId: env.firebaseProjectId,
        clientEmail: env.firebaseClientEmail,
        privateKey: env.firebasePrivateKey
      })
    });
  }

  return getAuth();
}
