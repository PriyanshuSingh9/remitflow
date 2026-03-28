import { ethers } from "ethers";
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

// ─── Singleton instances ───────────────────────────────────────────

let _provider: ethers.JsonRpcProvider | null = null;
let _operatorWallet: ethers.Wallet | null = null;
let _escrowContract: ethers.Contract | null = null;
let _usdcContract: ethers.Contract | null = null;

function getProvider(): ethers.JsonRpcProvider {
  if (!_provider) {
    _provider = new ethers.JsonRpcProvider(env.polygonRpcUrl);
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

// ─── Event Listener ────────────────────────────────────────────────

export function startEventListener() {
  if (!env.escrowContractAddress || !env.operatorPrivateKey) {
    console.log("[blockchain] Skipping event listener — missing contract address or operator key.");
    return;
  }

  const escrow = getEscrowContract();

  escrow.on("EscrowDeposited", async (escrowId: bigint, _sender: string, _receiver: string, _amount: bigint, _timestamp: bigint, event: any) => {
    const txHash = event.log?.transactionHash ?? "";
    console.log(`[event] EscrowDeposited id=${escrowId} tx=${txHash}`);
    try {
      await prisma.transaction.updateMany({
        where: { escrowId: Number(escrowId), escrowTxHash: null },
        data: { escrowTxHash: txHash, escrowState: "Deposited" },
      });
    } catch (err) {
      console.error("[event] Failed to update EscrowDeposited:", err);
    }
  });

  escrow.on("EscrowReleased", async (escrowId: bigint, _receiver: string, _amount: bigint, _timestamp: bigint, event: any) => {
    const txHash = event.log?.transactionHash ?? "";
    console.log(`[event] EscrowReleased id=${escrowId} tx=${txHash}`);
    try {
      await prisma.transaction.updateMany({
        where: { escrowId: Number(escrowId) },
        data: { releaseTxHash: txHash, escrowState: "Released" },
      });
    } catch (err) {
      console.error("[event] Failed to update EscrowReleased:", err);
    }
  });

  escrow.on("EscrowRefunded", async (escrowId: bigint, _sender: string, _amount: bigint, _timestamp: bigint, event: any) => {
    const txHash = event.log?.transactionHash ?? "";
    console.log(`[event] EscrowRefunded id=${escrowId} tx=${txHash}`);
    try {
      await prisma.transaction.updateMany({
        where: { escrowId: Number(escrowId) },
        data: { escrowState: "Refunded", status: "refunded" },
      });
    } catch (err) {
      console.error("[event] Failed to update EscrowRefunded:", err);
    }
  });

  console.log(`[blockchain] Event listener started for contract ${env.escrowContractAddress}`);
}
