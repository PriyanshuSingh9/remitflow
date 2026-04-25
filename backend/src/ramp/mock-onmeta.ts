import { prisma } from "../prisma";
import { env } from "../env";
import {
  confirmReadyForFunding,
  releaseEscrow,
  refundEscrow,
} from "./blockchain";

/** Generate a fake OnMeta-style order ID */
function generateOrderId(): string {
  return `OMT-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

/**
 * Create a mock off-ramp order and kick off the async processing pipeline.
 * In production this would POST to the OnMeta API.
 */
export async function createOffRampOrder(input: {
  transactionId: string;
  escrowId: number;
  fiatCurrency: string;
  fiatAmount: number;
  cryptoAmount: number;
  walletAddress: string;
  bankDetails?: string | null;
}): Promise<string> {
  const externalOrderId = generateOrderId();

  await prisma.rampOrder.create({
    data: {
      type: "offramp",
      transactionId: input.transactionId,
      externalOrderId,
      status: "CREATED",
      fiatCurrency: input.fiatCurrency,
      fiatAmount: input.fiatAmount,
      cryptoCurrency: "USDC",
      cryptoAmount: input.cryptoAmount,
      walletAddress: input.walletAddress,
      bankDetails: input.bankDetails,
    },
  });

  // Update transaction status
  await prisma.transaction.update({
    where: { id: input.transactionId },
    data: { status: "offramp_pending" },
  });

  // Fire and forget — the pipeline runs asynchronously
  processOffRampPipeline(input.transactionId, input.escrowId, externalOrderId).catch(
    (err) => console.error("[offramp] Pipeline failed:", err)
  );

  return externalOrderId;
}

/**
 * Async off-ramp pipeline. Simulates the real-world steps:
 *   1. Check liquidity / KYC (delay)
 *   2. Confirm ready_for_funding → call contract.confirmReadyForFunding()
 *   3. Release escrow → call contract.releaseEscrow()
 *   4. Execute fiat payout (delay)
 *   5. Mark completed
 */
async function processOffRampPipeline(
  transactionId: string,
  escrowId: number,
  externalOrderId: string
) {
  const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

  try {
    // Step 1 — Simulate liquidity / compliance check
    console.log(`[offramp] ${externalOrderId}: checking liquidity...`);
    await prisma.rampOrder.update({
      where: { externalOrderId },
      data: { status: "PENDING_LIQUIDITY" },
    });
    await delay(env.mockRampDelayMs / 2);

    // Step 2 — Ready for funding
    console.log(`[offramp] ${externalOrderId}: confirming ready_for_funding...`);
    await prisma.rampOrder.update({
      where: { externalOrderId },
      data: { status: "READY_FOR_FUNDING" },
    });
    await prisma.transaction.update({
      where: { id: transactionId },
      data: { status: "offramp_ready", escrowState: "ReadyForFunding" },
    });

    // Call on-chain confirmReadyForFunding
    await confirmReadyForFunding(escrowId);

    // Step 3 — Release escrow on-chain
    console.log(`[offramp] ${externalOrderId}: releasing escrow...`);
    const releaseTxHash = await releaseEscrow(escrowId);
    await prisma.rampOrder.update({
      where: { externalOrderId },
      data: { status: "FUNDED", txHash: releaseTxHash },
    });
    await prisma.transaction.update({
      where: { id: transactionId },
      data: {
        status: "escrow_released",
        escrowState: "Released",
        releaseTxHash,
      },
    });

    // Step 4 — Simulate fiat payout
    console.log(`[offramp] ${externalOrderId}: executing fiat transfer...`);
    await delay(Math.max(env.mockRampDelayMs / 2, 1000));

    // Step 5 — Completed
    await prisma.rampOrder.update({
      where: { externalOrderId },
      data: { status: "COMPLETED" },
    });
    await prisma.transaction.update({
      where: { id: transactionId },
      data: { status: "completed", completedAt: new Date() },
    });

    console.log(`[offramp] ${externalOrderId}: ✓ completed`);
  } catch (error) {
    console.error(`[offramp] ${externalOrderId}: FAILED`, error);

    let refundSucceeded = false;
    try {
      await refundEscrow(escrowId);
      refundSucceeded = true;
    } catch (refundError) {
      console.error(`[offramp] ${externalOrderId}: refund also failed`, refundError);
    }

    await prisma.rampOrder.update({
      where: { externalOrderId },
      data: { status: "FAILED" },
    });

    const transaction = await prisma.transaction.findUnique({
      where: { id: transactionId },
      select: { senderId: true, amountUsd: true },
    });

    if (refundSucceeded && transaction) {
      await prisma.$transaction([
        prisma.transaction.update({
          where: { id: transactionId },
          data: { status: "refunded", escrowState: "Refunded" },
        }),
        prisma.user.update({
          where: { id: transaction.senderId },
          data: {
            availableBalanceUsd: {
              increment: transaction.amountUsd,
            },
          },
        }),
      ]);
      return;
    }

    await prisma.transaction.update({
      where: { id: transactionId },
      data: { status: "failed" },
    });
  }
}
