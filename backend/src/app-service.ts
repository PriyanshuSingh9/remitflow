import type { DecodedIdToken } from "firebase-admin/auth";
import { prisma } from "./prisma";
import { env } from "./env";

const USD_INR_RATE = {
  baseCurrency: "USD",
  quoteCurrency: "INR",
  rate: 83.42,
  cheaperPercentage: 2.3
} as const;

const DEMO_RECIPIENTS = [
  {
    email: "priya.sharma@remitflow.demo",
    displayName: "Priya Sharma",
    photoUrl: "https://i.pravatar.cc/150?u=priya",
    country: "IN",
    walletAddress: "0x9C9f61d4F16B4cbC5BC9720b0B2d3e4F40AA1001",
    phoneNumber: "+919820000001"
  },
  {
    email: "rahul.verma@remitflow.demo",
    displayName: "Rahul Verma",
    photoUrl: "https://i.pravatar.cc/150?u=rahul",
    country: "IN",
    walletAddress: "0x9C9f61d4F16B4cbC5BC9720b0B2d3e4F40AA1002",
    phoneNumber: "+919820000002"
  },
  {
    email: "john.davis@remitflow.demo",
    displayName: "John Davis",
    photoUrl: "https://i.pravatar.cc/150?u=john",
    country: "US",
    walletAddress: "0x9C9f61d4F16B4cbC5BC9720b0B2d3e4F40AA1003",
    phoneNumber: "+12025550003"
  },
  {
    email: "sarah.smith@remitflow.demo",
    displayName: "Sarah Smith",
    photoUrl: "https://i.pravatar.cc/150?u=sarah",
    country: "IN",
    walletAddress: "0x9C9f61d4F16B4cbC5BC9720b0B2d3e4F40AA1004",
    phoneNumber: "+919820000004"
  }
] as const;

type SessionInput = {
  walletAddress?: string;
  country?: string;
  phoneNumber?: string;
};

type TransferInput = {
  recipientId: string;
  amountUsd: number;
};

function toNumber(value: { toString(): string } | number | null | undefined): number | null {
  if (value === null || value === undefined) {
    return null;
  }

  return Number(value.toString());
}

function requireEmail(token: DecodedIdToken): string {
  if (!token.email) {
    throw new Error("Authenticated Firebase user is missing an email address.");
  }

  return token.email.toLowerCase();
}

function fallbackWalletAddress(firebaseUid: string): string {
  const hex = Buffer.from(firebaseUid).toString("hex").padEnd(40, "0").slice(0, 40);
  return `0x${hex}`;
}

function roundMoney(value: number): number {
  return Number(value.toFixed(2));
}

function roundCrypto(value: number): number {
  return Number(value.toFixed(8));
}

async function ensureExchangeRate() {
  return prisma.exchangeRate.upsert({
    where: {
      baseCurrency_quoteCurrency: {
        baseCurrency: USD_INR_RATE.baseCurrency,
        quoteCurrency: USD_INR_RATE.quoteCurrency
      }
    },
    update: {
      rate: USD_INR_RATE.rate,
      cheaperPercentage: USD_INR_RATE.cheaperPercentage,
      asOf: new Date()
    },
    create: {
      ...USD_INR_RATE,
      asOf: new Date()
    }
  });
}

async function ensureDemoRecipients() {
  return Promise.all(
    DEMO_RECIPIENTS.map((recipient) =>
      prisma.user.upsert({
        where: { email: recipient.email },
        update: {
          displayName: recipient.displayName,
          photoUrl: recipient.photoUrl,
          phoneNumber: recipient.phoneNumber,
          country: recipient.country,
          walletAddress: recipient.walletAddress
        },
        create: {
          email: recipient.email,
          displayName: recipient.displayName,
          photoUrl: recipient.photoUrl,
          phoneNumber: recipient.phoneNumber,
          country: recipient.country,
          walletAddress: recipient.walletAddress,
          availableBalanceUsd: recipient.country === "US" ? 6400 : 0,
          lifetimeSavingsUsd: recipient.country === "US" ? 115.9 : 0
        }
      })
    )
  );
}

async function bootstrapUserData(userId: string) {
  const existingTransactionCount = await prisma.transaction.count({
    where: {
      OR: [{ senderId: userId }, { receiverId: userId }]
    }
  });

  if (existingTransactionCount > 0 || !env.enableDemoBootstrap) {
    return;
  }

  const recipients = await ensureDemoRecipients();
  const [priya, rahul, john] = recipients;
  const now = new Date();

  await prisma.$transaction([
    prisma.user.update({
      where: { id: userId },
      data: {
        availableBalanceUsd: 2450,
        lifetimeSavingsUsd: 348.71
      }
    }),
    prisma.transaction.createMany({
      data: [
        {
          senderId: userId,
          receiverId: priya.id,
          amountUsd: 500,
          amountUsdc: 500,
          amountInr: 41710,
          feeUsd: 4.25,
          status: "completed",
          createdAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
          completedAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000 + 25 * 60 * 1000)
        },
        {
          senderId: john.id,
          receiverId: userId,
          amountUsd: 1200,
          amountUsdc: 1200,
          amountInr: 100104,
          feeUsd: 0,
          status: "completed",
          createdAt: new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000),
          completedAt: new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000 + 40 * 60 * 1000)
        },
        {
          senderId: userId,
          receiverId: rahul.id,
          amountUsd: 250,
          amountUsdc: 250,
          amountInr: 20855,
          feeUsd: 2.12,
          status: "completed",
          createdAt: new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000),
          completedAt: new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000 + 30 * 60 * 1000)
        }
      ]
    })
  ]);
}

function serializeUser(user: {
  id: string;
  email: string;
  displayName: string | null;
  photoUrl: string | null;
  phoneNumber: string | null;
  walletAddress: string;
  country: string;
  availableBalanceUsd: { toString(): string };
  lifetimeSavingsUsd: { toString(): string };
}) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoUrl,
    phoneNumber: user.phoneNumber,
    walletAddress: user.walletAddress,
    country: user.country,
    availableBalanceUsd: toNumber(user.availableBalanceUsd) ?? 0,
    lifetimeSavingsUsd: toNumber(user.lifetimeSavingsUsd) ?? 0
  };
}

function serializeTransaction(
  transaction: {
    id: string;
    senderId: string;
    receiverId: string;
    amountUsd: { toString(): string };
    amountUsdc: { toString(): string };
    amountInr: { toString(): string };
    feeUsd: { toString(): string };
    txHash: string | null;
    status: string;
    createdAt: Date;
    completedAt: Date | null;
    sender: { id: string; displayName: string | null; email: string; photoUrl: string | null; country: string };
    receiver: { id: string; displayName: string | null; email: string; photoUrl: string | null; country: string };
  },
  currentUserId: string
) {
  const isSent = transaction.senderId === currentUserId;
  const counterparty = isSent ? transaction.receiver : transaction.sender;

  return {
    id: transaction.id,
    direction: isSent ? "sent" : "received",
    counterparty: {
      id: counterparty.id,
      displayName: counterparty.displayName,
      email: counterparty.email,
      photoUrl: counterparty.photoUrl,
      country: counterparty.country
    },
    amountUsd: toNumber(transaction.amountUsd) ?? 0,
    amountUsdc: toNumber(transaction.amountUsdc) ?? 0,
    amountInr: toNumber(transaction.amountInr) ?? 0,
    feeUsd: toNumber(transaction.feeUsd) ?? 0,
    txHash: transaction.txHash,
    status: transaction.status,
    createdAt: transaction.createdAt.toISOString(),
    completedAt: transaction.completedAt?.toISOString() ?? null
  };
}

export async function syncSessionFromToken(token: DecodedIdToken, input: SessionInput) {
  await ensureExchangeRate();

  const email = requireEmail(token);
  const existingUser = await prisma.user.findFirst({
    where: {
      OR: [{ firebaseUid: token.uid }, { email }]
    }
  });

  const user = existingUser
    ? await prisma.user.update({
        where: { id: existingUser.id },
        data: {
          firebaseUid: token.uid,
          email,
          displayName: token.name ?? existingUser.displayName,
          photoUrl: token.picture ?? existingUser.photoUrl,
          phoneNumber: input.phoneNumber ?? token.phone_number ?? existingUser.phoneNumber,
          walletAddress: input.walletAddress ?? existingUser.walletAddress,
          country: input.country ?? existingUser.country
        }
      })
    : await prisma.user.create({
        data: {
          firebaseUid: token.uid,
          email,
          displayName: token.name,
          photoUrl: token.picture,
          phoneNumber: input.phoneNumber ?? token.phone_number,
          walletAddress: input.walletAddress ?? fallbackWalletAddress(token.uid),
          country: input.country ?? "US"
        }
      });

  await bootstrapUserData(user.id);

  const refreshedUser = await prisma.user.findUniqueOrThrow({
    where: { id: user.id }
  });

  return { user: serializeUser(refreshedUser) };
}

export async function getCurrentUserByFirebaseUid(firebaseUid: string) {
  const user = await prisma.user.findUnique({
    where: { firebaseUid }
  });

  if (!user) {
    throw new Error("Authenticated user has not been synced to Neon yet.");
  }

  return user;
}

export async function getDashboard(currentUserId: string) {
  await ensureExchangeRate();

  const [user, exchangeRate, recentTransactions] = await Promise.all([
    prisma.user.findUniqueOrThrow({
      where: { id: currentUserId }
    }),
    prisma.exchangeRate.findUniqueOrThrow({
      where: {
        baseCurrency_quoteCurrency: {
          baseCurrency: USD_INR_RATE.baseCurrency,
          quoteCurrency: USD_INR_RATE.quoteCurrency
        }
      }
    }),
    prisma.transaction.findMany({
      where: {
        OR: [{ senderId: currentUserId }, { receiverId: currentUserId }]
      },
      include: {
        sender: true,
        receiver: true
      },
      orderBy: {
        createdAt: "desc"
      },
      take: 5
    })
  ]);

  return {
    user: serializeUser(user),
    exchangeRate: {
      baseCurrency: exchangeRate.baseCurrency,
      quoteCurrency: exchangeRate.quoteCurrency,
      rate: toNumber(exchangeRate.rate) ?? 0,
      cheaperPercentage: toNumber(exchangeRate.cheaperPercentage) ?? 0,
      asOf: exchangeRate.asOf.toISOString()
    },
    recentTransactions: recentTransactions.map((transaction: any) =>
      serializeTransaction(transaction, currentUserId)
    )
  };
}

export async function searchRecipients(currentUserId: string, query: string) {
  const search = query.trim();

  const recipients = await prisma.user.findMany({
    where: {
      id: { not: currentUserId },
      ...(search
        ? {
            OR: [
              { displayName: { contains: search, mode: "insensitive" } },
              { email: { contains: search, mode: "insensitive" } },
              { phoneNumber: { contains: search, mode: "insensitive" } }
            ]
          }
        : {})
    },
    orderBy: [{ displayName: "asc" }, { email: "asc" }],
    take: 12
  });

  return {
    recipients: recipients.map((recipient: any) => ({
      id: recipient.id,
      displayName: recipient.displayName,
      email: recipient.email,
      photoUrl: recipient.photoUrl,
      phoneNumber: recipient.phoneNumber,
      country: recipient.country
    }))
  };
}

export async function createTransfer(currentUserId: string, input: TransferInput) {
  if (!Number.isFinite(input.amountUsd) || input.amountUsd <= 0) {
    throw new Error("Transfer amount must be greater than zero.");
  }

  const result = await prisma.$transaction(async (tx: any) => {
    const [sender, recipient, exchangeRate] = await Promise.all([
      tx.user.findUnique({ where: { id: currentUserId } }),
      tx.user.findUnique({ where: { id: input.recipientId } }),
      tx.exchangeRate.findUnique({
        where: {
          baseCurrency_quoteCurrency: {
            baseCurrency: USD_INR_RATE.baseCurrency,
            quoteCurrency: USD_INR_RATE.quoteCurrency
          }
        }
      })
    ]);

    if (!sender) {
      throw new Error("Sender not found.");
    }

    if (!recipient) {
      throw new Error("Recipient not found.");
    }

    if (recipient.id === sender.id) {
      throw new Error("You cannot send money to yourself.");
    }

    if (!exchangeRate) {
      throw new Error("Exchange rate is unavailable.");
    }

    const senderBalance = toNumber(sender.availableBalanceUsd) ?? 0;
    if (senderBalance < input.amountUsd) {
      throw new Error("Insufficient balance for this transfer.");
    }

    const rate = toNumber(exchangeRate.rate) ?? 0;
    const feeUsd = roundMoney(input.amountUsd * 0.0085);
    const amountUsdc = roundCrypto(Math.max(input.amountUsd - feeUsd, 0));
    const amountInr = roundMoney(input.amountUsd * rate);

    await tx.user.update({
      where: { id: sender.id },
      data: {
        availableBalanceUsd: {
          decrement: input.amountUsd
        }
      }
    });

    const transaction = await tx.transaction.create({
      data: {
        senderId: sender.id,
        receiverId: recipient.id,
        amountUsd: input.amountUsd,
        amountUsdc,
        amountInr,
        feeUsd,
        status: "pending"
      },
      include: {
        sender: true,
        receiver: true
      }
    });

    return {
      transaction,
      senderBalanceAfter: roundMoney(senderBalance - input.amountUsd)
    };
  });

  return {
    transaction: serializeTransaction(result.transaction, currentUserId),
    senderBalanceAfter: result.senderBalanceAfter
  };
}
