import express from 'express';
import cors from 'cors';
import { OAuth2Client } from 'google-auth-library';
import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import { createHmac, randomUUID } from 'crypto';
import { prisma } from './prisma';

dotenv.config();

const app = express();

// Use the Web Client ID matching the Flutter google_sign_in package webClientId/serverClientId
const DEFAULT_GOOGLE_WEB_CLIENT_ID =
  "612184936512-j4tl40a3lmd793k0cirue0t2lca8660k.apps.googleusercontent.com";
const GOOGLE_CLIENT_ID =
  process.env.GOOGLE_CLIENT_ID || DEFAULT_GOOGLE_WEB_CLIENT_ID;
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_dev_key_for_remitflow';
const PORT = Number(process.env.PORT || 8787);
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);

app.use(cors());
app.use(express.json());

function signSessionToken(user: {
  id: string;
  email: string;
  walletAddress: string;
  name?: string | null;
  picture?: string | null;
}) {
  return jwt.sign(
    {
      userId: user.id,
      email: user.email,
      walletAddress: user.walletAddress,
      name: user.name ?? null,
      picture: user.picture ?? null,
    },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
}

function getBearerToken(authHeader?: string) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  return authHeader.slice('Bearer '.length).trim();
}

function deriveWalletAddressFromGoogleSubject(sub: string) {
  const privateKeyHex = createHmac('sha256', 'remitflow-wallet-v1')
    .update(sub)
    .digest('hex');
  return `0x${privateKeyHex}`;
}

app.post('/auth/google', async (req: any, res: any) => {
  const { idToken, walletAddress, country } = req.body;

  if (!idToken) {
    return res.status(400).json({ error: 'idToken is required' });
  }

  try {
    // 1. Verify the Google ID Token
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    if (!payload || !payload.email || !payload.sub) {
      return res.status(401).json({ error: 'Invalid Google token payload' });
    }

    const { email, name, picture, sub } = payload;
    const normalizedName = typeof name === 'string' && name.trim().length > 0 ? name.trim() : null;
    const normalizedPhotoUrl =
      typeof picture === 'string' && picture.trim().length > 0 ? picture.trim() : null;
    const normalizedWalletAddress =
      typeof walletAddress === 'string' && walletAddress.trim().length > 0
        ? walletAddress.trim()
        : deriveWalletAddressFromGoogleSubject(sub);
    const normalizedCountry =
      typeof country === 'string' && country.trim().length > 0 ? country.trim() : 'US';

    // 2. Map Google user to Neon Database User via Prisma
    // We keep the wallet deterministic from Google subject and make the row upsert-safe.
    let user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      // Create new user
      user = await prisma.user.create({
        data: {
          id: randomUUID(),
          email,
          walletAddress: normalizedWalletAddress,
          country: normalizedCountry,
          bankDetails: null,
          createdAt: new Date(),
          updatedAt: new Date(),
          firebaseUid: sub,
          displayName: normalizedName,
          photoUrl: normalizedPhotoUrl,
        },
      });
    } else if (
      normalizedWalletAddress !== user.walletAddress ||
      normalizedCountry !== user.country ||
      user.firebaseUid !== sub ||
      user.displayName !== normalizedName ||
      user.photoUrl !== normalizedPhotoUrl
    ) {
      user = await prisma.user.update({
        where: { email },
        data: {
          walletAddress: normalizedWalletAddress,
          country: normalizedCountry,
          firebaseUid: sub,
          displayName: normalizedName,
          photoUrl: normalizedPhotoUrl,
          updatedAt: new Date(),
        },
      });
    }

    // 3. Generate internal JWT session token
    const token = jwt.sign(
      {
        userId: user.id,
        email: user.email,
        walletAddress: user.walletAddress,
        name: name ?? null,
        picture: picture ?? null,
      },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        walletAddress: user.walletAddress,
        name: user.displayName ?? normalizedName,
        photoUrl: user.photoUrl ?? normalizedPhotoUrl,
        googleSubject: sub,
      },
    });

  } catch (error) {
    console.error('Google Signin Error:', error);
    const message = (error as Error).message;
    const status = /Wrong recipient|Token used too late|Invalid token|No pem found/i.test(message)
      ? 401
      : 500;
    res.status(status).json({ error: 'Authentication failed', details: message });
  }
});

app.get('/health', (_req: any, res: any) => {
  res.json({
    ok: true,
    port: PORT,
    googleClientIdConfigured: Boolean(GOOGLE_CLIENT_ID),
  });
});

app.get('/auth/me', async (req: any, res: any) => {
  const bearerToken = getBearerToken(req.headers.authorization);
  if (!bearerToken) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }

  try {
    const session = jwt.verify(bearerToken, JWT_SECRET) as {
      userId: string;
      email: string;
      walletAddress?: string;
      name?: string | null;
      picture?: string | null;
    };

    const user = await prisma.user.findUnique({
      where: { id: session.userId },
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.json({
      user: {
        id: user.id,
        email: user.email,
        walletAddress: user.walletAddress,
        name: user.displayName ?? session.name ?? null,
        photoUrl: user.photoUrl ?? session.picture ?? null,
      },
    });
  } catch (error) {
    return res.status(401).json({
      error: 'Invalid session',
      details: (error as Error).message,
    });
  }
});

app.listen(PORT, () => {
  console.log(`Backend pointing to Neon running on http://localhost:${PORT}`);
});
