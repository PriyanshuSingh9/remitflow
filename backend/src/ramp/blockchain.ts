import { ethers } from "ethers";
import { EventEmitter } from "node:events";
import { env } from "../env";
import { prisma } from "../prisma";

// ─── ABIs (minimal, only what we call) ─────────────────────────────

const ESCROW_ABI = [
  // Read
  "function nextEscrowId() view returns (uint256)",
  "function escrows(uint256) view returns (address sender, address receiver, uint256 amount, uint8 state, uint256 depositTimestamp)",
  "function ESCROW_TIMEOUT() view returns (uint256)",
  // Write
  "function operatorDeposit(address sender, address receiver, uint256 amount) returns (uint256 escrowId)",
  "function confirmReadyForFunding(uint256 escrowId)",
  "function releaseEscrow(uint256 escrowId)",
  "function refundEscrow(uint256 escrowId)",
  // Events
  "event EscrowDeposited(uint256 indexed escrowId, address indexed sender, address indexed receiver, uint256 amount, uint256 timestamp)",
  "event EscrowReadyForFunding(uint256 indexed escrowId, uint256 timestamp)",
  "event EscrowReleased(uint256 indexed escrowId, address indexed receiver, uint256 amount, uint256 timestamp)",
  "event EscrowRefunded(uint256 indexed escrowId, address indexed sender, uint256 amount, uint256 timestamp)",
];

const MOCK_USDC_ABI = [
  "function mint(address to, uint256 amount)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
];

// ─── Blockchain Event Emitter ──────────────────────────────────────

export const escrowEvents = new EventEmitter();

// ─── Singleton instances ───────────────────────────────────────────

let _provider: ethers.JsonRpcProvider | null = null;
let _operatorWallet: ethers.Wallet | null = null;
let _escrowContract: ethers.Contract | null = null;
let _usdcContract: ethers.Contract | null = null;

function getProvider(): ethers.JsonRpcProvider {
  if (!_provider) {
    _provider = new ethers.JsonRpcProvider(env.rpcUrl);
  }
  return _provider;
}

function getOperatorWallet(): ethers.Wallet {
  if (!_operatorWallet) {
    if (!env.operatorPrivateKey) {
      throw new Error("OPERATOR_PRIVATE_KEY is not set in environment.");
    }
    _operatorWallet = new ethers.Wallet(env.operatorPrivateKey, getProvider());
  }
  return _operatorWallet;
}

function getEscrowContract(): ethers.Contract {
  if (!_escrowContract) {
    if (!env.escrowContractAddress) {
      throw new Error("ESCROW_CONTRACT_ADDRESS is not set in environment.");
    }
    _escrowContract = new ethers.Contract(
      env.escrowContractAddress,
      ESCROW_ABI,
      getOperatorWallet()
    );
  }
  return _escrowContract;
}

function getUsdcContract(): ethers.Contract {
  if (!_usdcContract) {
    if (!env.usdcAddress) {
      throw new Error("USDC_ADDRESS is not set in environment.");
    }
    _usdcContract = new ethers.Contract(
      env.usdcAddress,
      MOCK_USDC_ABI,
      getOperatorWallet()
    );
  }
  return _usdcContract;
}

// ─── Public Functions ──────────────────────────────────────────────

/** Mint MockUSDC to a given address (Phase 1 only, anyone can call mint()) */
export async function mintMockUSDC(toAddress: string, amount: bigint) {
  const usdc = getUsdcContract();
  const tx = await usdc.mint(toAddress, amount);
  const receipt = await tx.wait();
  console.log(`[blockchain] minted ${amount} MockUSDC to ${toAddress} — tx ${receipt.hash}`);
  return receipt.hash as string;
}

/** Operator deposits USDC into escrow on behalf of sender */
export async function operatorDeposit(
  senderAddress: string,
  receiverAddress: string,
  amount: bigint
): Promise<{ escrowId: number; txHash: string }> {
  const usdc = getUsdcContract();
  const escrow = getEscrowContract();

  // 1. Approve escrow contract to spend operator's USDC
  const approveTx = await usdc.approve(env.escrowContractAddress, amount);
  await approveTx.wait();

  // 2. Call operatorDeposit
  const depositTx = await escrow.operatorDeposit(senderAddress, receiverAddress, amount);
  const receipt = await depositTx.wait();

  // 3. Parse EscrowDeposited event
  const iface = new ethers.Interface(ESCROW_ABI);
  let escrowId = -1;
  for (const log of receipt.logs) {
    try {
      const parsed = iface.parseLog({ topics: log.topics as string[], data: log.data });
      if (parsed?.name === "EscrowDeposited") {
        escrowId = Number(parsed.args.escrowId);
        break;
      }
    } catch {
      // skip non-matching logs
    }
  }

  console.log(`[blockchain] operatorDeposit escrowId=${escrowId} tx=${receipt.hash}`);
  return { escrowId, txHash: receipt.hash as string };
}

/** Confirm that off-ramp is ready to receive funds */
export async function confirmReadyForFunding(escrowId: number): Promise<string> {
  const escrow = getEscrowContract();
  const tx = await escrow.confirmReadyForFunding(escrowId);
  const receipt = await tx.wait();
  console.log(`[blockchain] confirmReadyForFunding escrowId=${escrowId} tx=${receipt.hash}`);
  return receipt.hash as string;
}

/** Release escrowed USDC to receiver (off-ramp wallet) */
export async function releaseEscrow(escrowId: number): Promise<string> {
  const escrow = getEscrowContract();
  const tx = await escrow.releaseEscrow(escrowId);
  const receipt = await tx.wait();
  console.log(`[blockchain] releaseEscrow escrowId=${escrowId} tx=${receipt.hash}`);
  return receipt.hash as string;
}

/** Refund escrowed USDC back to sender */
export async function refundEscrow(escrowId: number): Promise<string> {
  const escrow = getEscrowContract();
  const tx = await escrow.refundEscrow(escrowId);
  const receipt = await tx.wait();
  console.log(`[blockchain] refundEscrow escrowId=${escrowId} tx=${receipt.hash}`);
  return receipt.hash as string;
}

/** Read USDC balance for a wallet */
export async function getUSDCBalance(walletAddress: string): Promise<string> {
  const usdc = getUsdcContract();
  const balance = await usdc.balanceOf(walletAddress);
  return balance.toString();
}

/** Get operator wallet address */
export function getOperatorAddress(): string {
  return getOperatorWallet().address;
}

// ─── Block Poller (rate-limit friendly) ────────────────────────────

let _lastScannedBlock = 0;
let _pollBackoffMs = 0;
const POLL_INTERVAL_MS = 15_000; // 15 seconds — safe for free RPCs
const MAX_BACKOFF_MS = 120_000;

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function startEscrowPoller() {
  if (!env.escrowContractAddress || !env.operatorPrivateKey) {
    console.log("[blockchain] Skipping poller — missing contract address or operator key.");
    return;
  }

  const provider = getProvider();
  _lastScannedBlock = await provider.getBlockNumber();
  console.log(`[blockchain] Poller started from block ${_lastScannedBlock} (skipping history) on ${env.escrowContractAddress}`);

  const poll = async () => {
    try {
      // Backoff if we hit rate limits previously
      if (_pollBackoffMs > 0) {
        console.log(`[poller] Backing off ${_pollBackoffMs}ms...`);
        await delay(_pollBackoffMs);
      }

      const currentBlock = await provider.getBlockNumber();

      // Handle chain reset (e.g. Anvil restart with --load-state)
      if (currentBlock < _lastScannedBlock) {
        console.log(`[poller] Chain reset detected (block ${currentBlock} < ${_lastScannedBlock}). Re-syncing.`);
        _lastScannedBlock = currentBlock;
        return;
      }

      if (currentBlock <= _lastScannedBlock) return;

      const escrow = getEscrowContract();
      const fromBlock = _lastScannedBlock + 1;

      // Query events sequentially with small gaps to avoid rate limits
      const depositLogs = await escrow.queryFilter("EscrowDeposited", fromBlock, currentBlock);
      for (const log of depositLogs) {
        if ("args" in log) {
          const a = (log as any).args;
          console.log(`[poller] EscrowDeposited id=${a.escrowId} tx=${log.transactionHash}`);
          escrowEvents.emit("EscrowDeposited", {
            escrowId: Number(a.escrowId),
            sender: a.sender as string,
            receiver: a.receiver as string,
            amount: a.amount as bigint,
            txHash: log.transactionHash,
          });
        }
      }

      await delay(500); // gap between RPC calls

      const releaseLogs = await escrow.queryFilter("EscrowReleased", fromBlock, currentBlock);
      for (const log of releaseLogs) {
        if ("args" in log) {
          const a = (log as any).args;
          console.log(`[poller] EscrowReleased id=${a.escrowId} tx=${log.transactionHash}`);
          escrowEvents.emit("EscrowReleased", {
            escrowId: Number(a.escrowId),
            txHash: log.transactionHash,
          });
        }
      }

      await delay(500);

      const refundLogs = await escrow.queryFilter("EscrowRefunded", fromBlock, currentBlock);
      for (const log of refundLogs) {
        if ("args" in log) {
          const a = (log as any).args;
          console.log(`[poller] EscrowRefunded id=${a.escrowId} tx=${log.transactionHash}`);
          escrowEvents.emit("EscrowRefunded", {
            escrowId: Number(a.escrowId),
            txHash: log.transactionHash,
          });
        }
      }

      _lastScannedBlock = currentBlock;
      _pollBackoffMs = 0; // reset backoff on success
    } catch (err: any) {
      const isRateLimited = err?.message?.includes("Too Many Requests") || err?.code === -32005;
      if (isRateLimited) {
        _pollBackoffMs = Math.min((_pollBackoffMs || POLL_INTERVAL_MS) * 2, MAX_BACKOFF_MS);
        console.warn(`[poller] Rate limited — backing off to ${_pollBackoffMs}ms`);
      } else {
        console.error("[poller] Poll error:", err);
      }
    }
  };

  // Use recursive setTimeout instead of setInterval to prevent overlap
  const schedulePoll = () => {
    setTimeout(async () => {
      await poll();
      schedulePoll();
    }, POLL_INTERVAL_MS);
  };
  schedulePoll();
}

