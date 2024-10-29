import { Address, Hex, getContractAddress } from "viem";
import { createPromptModule } from "inquirer";

const prompt = createPromptModule();

prompt([
  {
    type: "list",
    name: "opcode",
    message: "Choose an opcode:",
    choices: ["CREATE", "CREATE2"],
  },
  {
    type: "input",
    name: "from",
    message: "Enter from address:",
    default: "0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266",
    filter: (value) => value as Address,
  },
  {
    type: "input",
    name: "nonce",
    message: "Enter nonce:",
    default: "420",
    when: (answers) => answers.opcode === "CREATE",
    filter: (value) => BigInt(value),
  },
  {
    type: "input",
    name: "bytecode",
    message: "Enter bytecode",
    default:
      "0x608060405234801561000f575f80fd5b506004361061004a575f3560e01c806306661abd1461004e578063371303c01461006c5780636d4ce63c14610076578063b3bcfa8214610094575b5f80fd5b61005661009e565b60405161006391906100f7565b60405180910390f35b6100746100a3565b005b61007e6100bd565b60405161008b91906100f7565b60405180910390f35b61009c6100c5565b005b5f5481565b60015f808282546100b4919061013d565b92505081905550565b5f8054905090565b60015f808282546100d69190610170565b92505081905550565b5f819050919050565b6100f1816100df565b82525050565b5f60208201905061010a5f8301846100e8565b92915050565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52601160045260245ffd5b5f610147826100df565b9150610152836100df565b925082820190508082111561016a57610169610110565b5b92915050565b5f61017a826100df565b9150610185836100df565b925082820390508181111561019d5761019c610110565b5b9291505056fea26469706673582212207e792fcff28a4bf0bad8675c5bc2288b07835aebaa90b8dc5e0df19183fb72cf64736f6c63430008160033",
    when: (answers) => answers.opcode === "CREATE2",
    filter: (value) => value as Hex,
  },
  {
    type: "input",
    name: "salt",
    message: "Enter salt or press Enter for default [0xbeef]:",
    default: "0xbeef",
    when: (answers) => answers.opcode === "CREATE2",
    filter: (value) => value.startsWith("0x") ? (value as Hex) : ("0x" + value as Hex),
  },
]).then((answers) => {
  let address: Address;
  if (answers.opcode === "CREATE") {
    address = getContractAddress({
      opcode: "CREATE",
      from: answers.from as Address,
      nonce: answers.nonce as BigInt,
    });
  } else if (answers.opcode === "CREATE2") {
    address = getContractAddress({
      opcode: "CREATE2",
      from: answers.from as Address,
      bytecode: answers.bytecode as Hex,
      salt: answers.salt as Hex,
    });
  }

  console.log(`Generated Address: ${address}`);
});
