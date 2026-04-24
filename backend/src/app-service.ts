import { prisma } from "./prisma";
import { env } from "./env";

const USD_INR_FALLBACK_RATE = 83.42;

const USD_INR_RATE = {
  baseCurrency: "USD",
  quoteCurrency: "INR",
  rate: USD_INR_FALLBACK_RATE,
  cheaperPercentage: 2.3
} as const;

/** Fetch the live USD → INR rate from the same public API the mobile app uses. */
async function fetchLiveUsdInrRate(): Promise<number> {
  try {
    const res = await fetch("https://open.er-api.com/v6/latest/USD");
    if (res.ok) {
      const data = await res.json();
      if (data.result === "success" && data.rates?.INR) {
        return Number(data.rates.INR);
      }
    }
  } catch (err) {
    console.warn("[exchange-rate] Failed to fetch live rate, using fallback:", err);
  }
  return USD_INR_FALLBACK_RATE;
}

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

type GoogleIdentity = {
  sub: string;
  email?: string | null;
  name?: string | null;
  picture?: string | null;
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

function requireEmail(identity: GoogleIdentity): string {
  if (!identity.email) {
    throw new Error("Authenticated Google user is missing an email address.");
  }

  return identity.email.toLowerCase();
}

function fallbackWalletAddress(googleSubject: string): string {
  const hex = Buffer.from(googleSubject).toString("hex").padEnd(40, "0").slice(0, 40);
  return `0x${hex}`;
}

function roundMoney(value: number): number {
  return Number(value.toFixed(2));
}

function roundCrypto(value: number): number {
  return Number(value.toFixed(8));
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

export async function syncSessionFromGoogleIdentity(identity: GoogleIdentity, input: SessionInput) {
  const email = requireEmail(identity);
  const existingUser = await prisma.user.findFirst({
    where: {
      OR: [{ googleSubject: identity.sub }, { email }]
    }
  });

  const user = existingUser
    ? await prisma.user.update({
        where: { id: existingUser.id },
        data: {
          googleSubject: identity.sub,
          email,
          displayName: identity.name ?? existingUser.displayName,
          photoUrl: identity.picture ?? existingUser.photoUrl,
          phoneNumber: input.phoneNumber ?? existingUser.phoneNumber,
          walletAddress: input.walletAddress ?? existingUser.walletAddress,
          country: input.country ?? existingUser.country
        }
      })
    : await prisma.user.create({
        data: {
          googleSubject: identity.sub,
          email,
          displayName: identity.name ?? null,
          photoUrl: identity.picture ?? null,
          phoneNumber: input.phoneNumber ?? null,
          walletAddress: input.walletAddress ?? fallbackWalletAddress(identity.sub),
          country: input.country ?? "US"
        }
      });

  await bootstrapUserData(user.id);

  const refreshedUser = await prisma.user.findUniqueOrThrow({
    where: { id: user.id }
  });

  return { user: serializeUser(refreshedUser) };
}

export async function getCurrentUserByGoogleSubject(googleSubject: string) {
  const user = await prisma.user.findUnique({
    where: { googleSubject }
  });

  if (!user) {
    throw new Error("Authenticated user has not been synced to Neon yet.");
  }

  return user;
}

export async function getDashboard(currentUserId: string) {
  const [user, recentTransactions, liveRate] = await Promise.all([
    prisma.user.findUniqueOrThrow({
      where: { id: currentUserId }
    }),
    prisma.transaction.findMany({
      where: {
        senderId: currentUserId
      },
      include: {
        sender: true,
        receiver: true
      },
      orderBy: {
        createdAt: "desc"
      },
      take: 5
    }),
    fetchLiveUsdInrRate()
  ]);

  return {
    user: serializeUser(user),
    exchangeRate: {
      baseCurrency: USD_INR_RATE.baseCurrency,
      quoteCurrency: USD_INR_RATE.quoteCurrency,
      rate: liveRate,
      cheaperPercentage: USD_INR_RATE.cheaperPercentage,
      asOf: new Date().toISOString()
    },
    recentTransactions: recentTransactions.map((transaction: any) =>
      serializeTransaction(transaction, currentUserId)
    )
  };
}

export async function getReceiverDashboard(currentUserId: string) {
  const [user, receivedTransactions] = await Promise.all([
    prisma.user.findUniqueOrThrow({
      where: { id: currentUserId }
    }),
    prisma.transaction.findMany({
      where: {
        receiverId: currentUserId
      },
      include: {
        sender: true,
        receiver: true
      },
      orderBy: {
        createdAt: "desc"
      },
      take: 20
    })
  ]);

  const totalReceivedInr = receivedTransactions.reduce(
    (sum: number, tx: any) => sum + (toNumber(tx.amountInr) ?? 0),
    0
  );

  return {
    user: serializeUser(user),
    totalReceivedInr: roundMoney(totalReceivedInr),
    receivedTransactions: receivedTransactions.map((transaction: any) =>
      serializeTransaction(transaction, currentUserId)
    )
  };
}

export async function searchRecipients(currentUserId: string, query: string) {
  const search = query.trim();

  const recipients = await prisma.user.findMany({
    where: {
      id: { not: currentUserId },
      country: "IN",
      ...(search
        ? {
            OR: [
              { displayName: { contains: search, mode: "insensitive" } },
              { email: { contains: search, mode: "insensitive" } }
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
    const [sender, recipient] = await Promise.all([
      tx.user.findUnique({ where: { id: currentUserId } }),
      tx.user.findUnique({ where: { id: input.recipientId } })
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

    const senderBalance = toNumber(sender.availableBalanceUsd) ?? 0;
    if (senderBalance < input.amountUsd) {
      throw new Error("Insufficient balance for this transfer.");
    }

    const rate = await fetchLiveUsdInrRate();
    const usdToUsdc = 1.0; // 1:1 for mock
    
    // Match frontend fee structure: 3.25% + $0.01 flat gas
    const feeUsd = roundMoney(input.amountUsd * 0.0325 + 0.01);
    
    // Receiver gets amount after 3.25% fee (gas is protocol-level, paid separately from received amount in frontend logic)
    const receivedUsd = input.amountUsd * (1 - 0.0325);
    const amountUsdc = roundCrypto(Math.max(receivedUsd, 0));
    const amountInr = roundMoney(receivedUsd * rate);

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
        status: "pending",
        lockedUsdToUsdc: usdToUsdc,
        lockedUsdcToInr: rate
      },
      include: {
        sender: true,
        receiver: true
      }
    });

    return {
      transaction,
      senderWalletAddress: sender.walletAddress,
      senderBalanceAfter: roundMoney(senderBalance - input.amountUsd)
    };
  });

  // Create mock on-ramp order
  const { createOnRampOrder } = await import("./ramp/mock-transak");
  const { orderId, widgetUrl } = await createOnRampOrder({
    transactionId: result.transaction.id,
    fiatCurrency: "USD",
    fiatAmount: input.amountUsd,
    cryptoAmount: toNumber(result.transaction.amountUsdc) ?? 0,
    walletAddress: result.senderWalletAddress
  });

  // Auto-complete the on-ramp (no separate Transak widget step needed)
  // Fire in the background so the API response isn't delayed
  setImmediate(async () => {
    try {
      console.log(`[auto-onramp] Triggering completeOnRamp for order ${orderId}`);
      await completeOnRamp(orderId);
      console.log(`[auto-onramp] Successfully completed on-ramp for order ${orderId}`);
    } catch (err) {
      console.error(`[auto-onramp] Failed for order ${orderId}:`, err);
    }
  });

  return {
    transaction: serializeTransaction(result.transaction, currentUserId),
    senderBalanceAfter: result.senderBalanceAfter,
    onRampOrderId: orderId,
    widgetUrl
  };
}

export async function completeOnRamp(externalOrderId: string) {
  const { completeOnRampOrder } = await import("./ramp/mock-transak");
  const order = await completeOnRampOrder(externalOrderId);
  const transaction = order.transaction;

  if (!transaction) {
    throw new Error("Transaction not found for on-ramp order.");
  }

  const sender = await prisma.user.findUnique({ where: { id: transaction.senderId } });
  const receiver = await prisma.user.findUnique({ where: { id: transaction.receiverId } });

  if (!sender || !receiver) {
    throw new Error("Sender or receiver not found.");
  }

  const amountUsdc = toNumber(transaction.amountUsdc) ?? 0;
  // USDC has 6 decimals
  const amountOnChain = BigInt(Math.round(amountUsdc * 1_000_000));

  // 1. Mint MockUSDC to operator
  const { mintMockUSDC, operatorDeposit, getOperatorAddress } = await import("./ramp/blockchain");
  const operatorAddress = getOperatorAddress();
  await mintMockUSDC(operatorAddress, amountOnChain);

  // 2. Operator deposits to escrow
  const { escrowId, txHash } = await operatorDeposit(
    sender.walletAddress,
    receiver.walletAddress,
    amountOnChain
  );

  // 3. Update transaction
  await prisma.transaction.update({
    where: { id: transaction.id },
    data: {
      status: "escrow_locked",
      escrowId,
      escrowTxHash: txHash,
      escrowState: "Deposited"
    }
  });

  // 4. Kick off off-ramp pipeline
  const { createOffRampOrder } = await import("./ramp/mock-onmeta");
  await createOffRampOrder({
    transactionId: transaction.id,
    escrowId,
    fiatCurrency: "INR",
    fiatAmount: toNumber(transaction.amountInr) ?? 0,
    cryptoAmount: amountUsdc,
    walletAddress: receiver.walletAddress,
    bankDetails: receiver.bankDetails
  });

  return {
    transactionId: transaction.id,
    escrowId,
    escrowTxHash: txHash,
    status: "escrow_locked"
  };
}

export async function getTransferDetail(transactionId: string, currentUserId: string) {
  const transaction = await prisma.transaction.findUnique({
    where: { id: transactionId },
    include: {
      sender: true,
      receiver: true,
      rampOrders: {
        orderBy: { createdAt: "asc" }
      }
    }
  });

  if (!transaction) {
    throw new Error("Transfer not found.");
  }

  if (transaction.senderId !== currentUserId && transaction.receiverId !== currentUserId) {
    throw new Error("You do not have access to this transfer.");
  }

  const onRampOrder = transaction.rampOrders.find((o: any) => o.type === "onramp");
  const offRampOrder = transaction.rampOrders.find((o: any) => o.type === "offramp");

  return {
    transaction: serializeTransaction(transaction, currentUserId),
    lockedUsdToUsdc: toNumber(transaction.lockedUsdToUsdc),
    lockedUsdcToInr: toNumber(transaction.lockedUsdcToInr),
    escrowId: transaction.escrowId,
    escrowState: transaction.escrowState,
    escrowTxHash: transaction.escrowTxHash,
    releaseTxHash: transaction.releaseTxHash,
    onRampStatus: onRampOrder?.status ?? null,
    offRampStatus: offRampOrder?.status ?? null
  };
}


