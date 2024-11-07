import { ethers } from "ethers";
import dotenv from "dotenv";
import readline from "readline";
import { readFileSync, existsSync } from "fs";

dotenv.config();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const question = (query: string): Promise<string> => {
  return new Promise((resolve) => {
    rl.question(query, (answer) => {
      resolve(answer);
    });
  });
};

const main = async () => {
  const { Transaction, Wallet, keccak256, RLP } = ethers;

  if (!process.env.PRIVATE_KEY_RLP_SCRIPT) {
    console.error(
      "Missing private key in environment. Please provide PRIVATE_KEY_RLP_SCRIPT in .env",
    );
    process.exit(1);
  }

  const wallet = new Wallet(process.env.PRIVATE_KEY_RLP_SCRIPT);
  console.log("Address of the wallet:", wallet.address);

  let tx_type = parseInt(
    await question(
      "Enter transaction type (0: legacy, 1: 2930, 2: 1559, 3: inc_counter, 4: y_parity_false eip1559): ",
    ),
  );

  let txFilePath: string;
  switch (tx_type) {
    case 0:
      txFilePath = "./scripts/data/input_legacy_tx.json";
      break;
    case 1:
      txFilePath = "./scripts/data/input_access_list_tx.json";
      break;
    case 2:
      txFilePath = "./scripts/data/input_fee_tx.json";
      break;
    case 3:
      tx_type = 1;
      txFilePath = "./scripts/data/input_eip_2930_counter_inc_tx.json";
      break;
    case 4:
      tx_type = 2;
      txFilePath = "./scripts/data/input_eip1559_y_parity_false.json";
      break;
    default:
      throw new Error(`Invalid transaction type: ${tx_type}`);
  }

  if (!existsSync(txFilePath)) {
    throw new Error(`Transaction file not found: ${txFilePath}`);
  }

  const tx = JSON.parse(readFileSync(txFilePath, "utf-8"));
  const transaction = Transaction.from(tx);
  transaction.type = tx_type;

  const signed_tx = await wallet.signTransaction(transaction);
  console.log("Unsigned serialized tx:", transaction.unsignedSerialized);
  console.log("Unsigned transaction hash:", transaction.hash);

  const unsignedBytes = ethers.getBytes(transaction.unsignedSerialized);
  console.log("Unsigned RLP encoded bytes:");
  console.log(unsignedBytes.map((v) => `${v},`).join(" "));

  const unsignedBytes2 = Uint8Array.from(
    transaction.type === 0 ? unsignedBytes : unsignedBytes.slice(1),
  );
  let decodedRlp = RLP.decode(unsignedBytes2);
  console.log("Decoded RLP for unsigned transaction:\n", decodedRlp);

  const signedBytes = ethers.getBytes(signed_tx);
  console.log("Signed RLP encoded bytes:");
  console.log(signedBytes.map((v) => `${v},`).join(" "));

  const signedBytes2 = Uint8Array.from(
    transaction.type === 0 ? signedBytes : signedBytes.slice(1),
  );
  decodedRlp = RLP.decode(signedBytes2);
  console.log("Signed decoded RLP for signed transaction:\n", decodedRlp);

  const hash = keccak256(unsignedBytes);
  console.log("Hash over which the signature was made:", hash);

  console.log("Signature details:");
  const v = decodedRlp[decodedRlp.length - 3];
  const r = decodedRlp[decodedRlp.length - 2];
  const s = decodedRlp[decodedRlp.length - 1];

  const y_parity =
    tx_type === 0
      ? get_y_parity(BigInt(v), BigInt(tx.chainId))
      : parseInt(v, 16) === 1;
  console.log("r:", r);
  console.log("s:", s);
  if (tx_type === 0) {
    console.log("v:", v);
  }
  console.log("y parity:", y_parity);

  rl.close();
  process.exit(0);
};

const get_y_parity = (v: bigint, chain_id: bigint): boolean => {
  let y_parity = v - (chain_id * BigInt(2) + BigInt(35));
  if (y_parity === BigInt(0) || y_parity === BigInt(1)) {
    return y_parity === BigInt(1);
  }

  y_parity = v - (chain_id * BigInt(2) + BigInt(36));
  if (y_parity === BigInt(0) || y_parity === BigInt(1)) {
    return y_parity === BigInt(1);
  }

  throw new Error("Invalid v value");
};

main();
