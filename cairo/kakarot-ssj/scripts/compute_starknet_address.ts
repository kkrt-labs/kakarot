import { hash } from "starknet";
import inquirer from "inquirer";

inquirer
  .prompt([
    {
      type: "input",
      name: "classHashInput",
      message: "Enter the class hash:",
      validate: (input) => {
        if (!/^0x[0-9a-fA-F]+$/.test(input.trim())) {
          return "Please enter a valid hexadecimal class hash.";
        }
        return true;
      },
    },
    {
      type: "input",
      name: "saltInput",
      message: "Enter the salt:",
      default: "0x65766d5f61646472657373",
      validate: (input) => {
        if (!/^0x[0-9a-fA-F]+$/.test(input.trim())) {
          return "Please enter a valid hexadecimal salt.";
        }
        return true;
      },
    },
    {
      type: "input",
      name: "deployerInput",
      message: "Enter the deployer address:",
      default:
        "0x7753aaa1814b9f978fd93b66453ae87419b66d764fbf9313847edeb0283ef63",
      validate: (input) => {
        if (!/^0x[0-9a-fA-F]+$/.test(input.trim())) {
          return "Please enter a valid hexadecimal deployer address.";
        }
        return true;
      },
    },
  ])
  .then((answers) => {
    const classHash = BigInt(answers.classHashInput);
    const salt = BigInt(answers.saltInput);
    const deployerAddress = BigInt(answers.deployerInput);

    const CONSTRUCTOR_CALLDATA = [deployerAddress, salt];

    function computeStarknetAddress() {
      return hash.calculateContractAddressFromHash(
        salt,
        classHash,
        CONSTRUCTOR_CALLDATA,
        deployerAddress,
      );
    }

    console.log("Pre-computed Starknet Address:", computeStarknetAddress());
  });
