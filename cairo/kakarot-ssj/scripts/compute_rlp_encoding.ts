// This js script helps in creating unsigned and signed RLP data for tests

import { ethers, toBeArray } from "ethers";
import dotevn from "dotenv";
import readline from "readline";
import { readFileSync } from "fs";

dotevn.config();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const question = (query: string): Promise<string> => {
  return new Promise((resolve, reject) => {
    rl.question(query, (answer) => {
      resolve(answer);
    });
  });
};

const main = async () => {
  const { Transaction, Wallet } = ethers;
  const { decodeRlp, getBytes } = ethers;

  if (!process.env.PRIVATE_KEY) {
    console.log(
      "missing private key in environment, please provide PRIVATE_KEY environment variable",
    );
    process.exit(1);
  }

  const wallet = new Wallet(process.env.PRIVATE_KEY);
  console.log("address of the wallet is", wallet.address);

  let tx_type = parseInt(
    await question(
      "enter transaction, 0: legacy, 1: 2930, 2:1559, 3: inc_counter, 4: y_parity_false eip1559: ",
    ),
  );

  // for type 0 and type 1
  let tx;

  switch (tx_type) {
    case 0:
      tx = JSON.parse(
        readFileSync("./scripts/data/input_legacy_tx.json", "utf-8"),
      );
      break;
    case 1:
      tx = JSON.parse(
        readFileSync("./scripts/data/input_access_list_tx.json", "utf-8"),
      );
      break;
    case 2:
      tx = JSON.parse(
        readFileSync("./scripts/data/input_fee_tx.json", "utf-8"),
      );
      break;
    case 3:
      tx_type = 1;
      tx = JSON.parse(
        readFileSync(
          "./scripts/data/input_eip_2930_counter_inc_tx.json",
          "utf-8",
        ),
      );
      break;
    case 4:
      tx_type = 2;
      tx = JSON.parse(
        readFileSync(
          "./scripts/data/input_eip1559_y_parity_false.json",
          "utf-8",
        ),
      );
      break;
    default:
      throw new Error(
        `transaction type ${tx_type} isn't a valid transaction type`,
      );
  }

  const transaction = Transaction.from(tx);
  transaction.type = tx_type;

  let signed_tx = await wallet.signTransaction(transaction);

  console.log("unsigned serialized tx ----->", transaction.unsignedSerialized);
  console.log("unsigned transaction hash", transaction.hash);

  // const bytes = getBytes(signedTX);
  const bytes = getBytes(transaction.unsignedSerialized);

  console.log("unsigned RLP encoded bytes for the transaction: ");

  // this prints unsigned RLP encoded bytes of the transaction
  bytes.forEach((v) => {
    console.log(v, ",");
  });
  console.log("\n");

  let bytes2 = Uint8Array.from(transaction.type == 0 ? bytes : bytes.slice(1));

  let decodedRlp = decodeRlp(bytes2);
  console.log("decoded RLP is for unsigned transaction ....\n", decodedRlp);

  let bytes3 = getBytes(signed_tx);

  console.log("signed RLP encoded bytes for the transaction: ");

  // this prints unsigned RLP encoded bytes of the transaction
  bytes3.forEach((v) => {
    console.log(v, ",");
  });
  console.log("\n");

  bytes3 = Uint8Array.from(transaction.type == 0 ? bytes3 : bytes3.slice(1));
  decodedRlp = decodeRlp(bytes3);
  console.log("signed decoded RLP for signed transaction ....\n", decodedRlp);

  const hash = ethers.keccak256(bytes);
  console.log("the hash over which the signature was made:", hash);

  console.log("signature details: ");
  const v = decodedRlp[decodedRlp.length - 3];
  const r = decodedRlp[decodedRlp.length - 2];
  const s = decodedRlp[decodedRlp.length - 1];

  const y_parity =
    tx_type == 0
      ? get_y_parity(BigInt(v), BigInt(tx.chainId))
      : parseInt(v, 16) == 1;
  console.log("r: ", r);
  console.log("s: ", s);
  if (tx_type == 0) {
    console.log("v: ", v);
  }
  console.log("y parity: ", y_parity);

  process.exit(0);
};

const get_y_parity = (v: bigint, chain_id: bigint): boolean => {
  let y_parity = v - (chain_id * BigInt(2) + BigInt(35));
  if (y_parity == BigInt(0) || y_parity == BigInt(1)) {
    return y_parity == BigInt(1);
  }

  y_parity = v - (chain_id * BigInt(2) + BigInt(36));
  if (y_parity == BigInt(0) || y_parity == BigInt(1)) {
    return y_parity == BigInt(1);
  }

  throw new Error("invalid v value");
};

main();
