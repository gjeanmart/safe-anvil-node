import { task, type HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import {
  Address,
  Hex,
  createWalletClient,
  defineChain,
  getAddress,
  getCreate2Address,
  http,
  parseEther,
} from "viem";
import { mnemonicToAccount } from "viem/accounts";
import {
  PublicClient,
  WalletClient,
} from "@nomicfoundation/hardhat-viem/types";
import {
  getSingletonFactoryInfo,
  SingletonFactoryInfo,
} from "@safe-global/safe-singleton-factory";
import artifacts from "./utils/artifacts1_3_0.json";

async function deploySingletons(client: PublicClient, relayer: WalletClient) {
  const factoryAddress = await deploySingletonFactory(client, relayer);
  const safeMastercopyAddress = await deploySingleton(
    client,
    relayer,
    factoryAddress,
    artifacts.safe_L2 as Hex,
  );
  const safeProxyFactoryAddress = await deploySingleton(
    client,
    relayer,
    factoryAddress,
    artifacts.proxy_factory as Hex,
  );
  const safeMultiSendAddress = await deploySingleton(
    client,
    relayer,
    factoryAddress,
    artifacts.multisend as Hex,
  );
  const safeMultiSendCallOnlyAddress = await deploySingleton(
    client,
    relayer,
    factoryAddress,
    artifacts.multisend_call_only as Hex,
  );
  const safeFallbackHandlerAddress = await deploySingleton(
    client,
    relayer,
    factoryAddress,
    artifacts.fallback_handler as Hex,
  );
  const safeSignMessageLibAddress = await deploySingleton(
    client,
    relayer,
    factoryAddress,
    artifacts.sign_message_lib as Hex,
  );
  const safeCreateCallAddress = await deploySingleton(
    client,
    relayer,
    factoryAddress,
    artifacts.create_call as Hex,
  );
  const safeSimulateTxAccessorAddress = await deploySingleton(
    client,
    relayer,
    factoryAddress,
    artifacts.simulate_tx_accessor as Hex,
  );

  return {
    safeMastercopyAddress,
    safeProxyFactoryAddress,
    safeMultiSendAddress,
    safeMultiSendCallOnlyAddress,
    safeFallbackHandlerAddress,
    safeSignMessageLibAddress,
    safeCreateCallAddress,
    safeSimulateTxAccessorAddress,
  };
}

async function isContract(client: PublicClient, address: Address) {
  const code = await client.getBytecode({ address });
  return code !== undefined;
}

async function deploySingletonFactory(
  client: PublicClient,
  relayer: WalletClient,
): Promise<Address> {
  if (process.env.DETERMINISTIC_DEPLOYMENT === "true") {
    const chainId = await client.getChainId();

    const { address, signerAddress, transaction } = getSingletonFactoryInfo(
      chainId,
    ) as SingletonFactoryInfo;
    const addressFormated = getAddress(address);

    if (await isContract(client, addressFormated)) {
      // Singleton factory already deployed...
      return addressFormated;
    }

    // fund the presined transaction signer
    const fundingHash = await relayer.sendTransaction({
      to: getAddress(signerAddress),
      value: parseEther("0.1"),
    });

    // Wait for the funding transaction to be mined
    await client.waitForTransactionReceipt({ hash: fundingHash });

    // shoot the presigned transaction
    // Note: Use ethers because sendRawTransaction not working
    await client.sendRawTransaction({
      serializedTransaction: transaction as Hex,
    });

    return addressFormated;
  } else {
    const hash = await relayer.deployContract({
      bytecode:
        "0x604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3",
      abi: [],
    });
    const receipt = await client.waitForTransactionReceipt({ hash });
    return receipt.contractAddress as Address;
  }
}

async function deploySingleton(
  client: PublicClient,
  relayer: WalletClient,
  factory: Address,
  bytecode: Hex,
): Promise<Address> {
  const salt =
    "0x0000000000000000000000000000000000000000000000000000000000000000";
  const create2Addr = getCreate2Address({ bytecode, from: factory, salt });

  if (await isContract(client, create2Addr)) {
    // Singleton already deployed...
    return create2Addr;
  }

  const hash = await relayer.sendTransaction({
    to: factory,
    data: `${salt}${bytecode.slice(2)}`,
  });

  // Wait for the deployment transaction to be mined
  await client.waitForTransactionReceipt({ hash });

  return getCreate2Address({ bytecode, from: factory, salt });
}

task("deploy", "Deploys Safe's singletons").setAction(
  async (_taskArgs, hre) => {
    await hre.run("compile");

    const rpcEndpoint = `http://127.0.0.1:${process.env.RPC_PORT}`;
    const chain = defineChain({
      id: Number(process.env.CHAIN_ID),
      name: "anvil",
      nativeCurrency: { decimals: 18, name: "Ether", symbol: "ETH" },
      rpcUrls: { default: { http: [rpcEndpoint] } },
    });
    const client = await hre.viem.getPublicClient({
      chain,
      transport: http(rpcEndpoint),
    });
    const deployer = createWalletClient({
      account: mnemonicToAccount(process.env.MNEMONIC + ""),
      chain,
      transport: http(rpcEndpoint),
    });

    // Deploy all singletons
    const {
      safeMastercopyAddress,
      safeProxyFactoryAddress,
      safeMultiSendAddress,
      safeMultiSendCallOnlyAddress,
      safeFallbackHandlerAddress,
      safeSignMessageLibAddress,
      safeCreateCallAddress,
      safeSimulateTxAccessorAddress,
    } = await deploySingletons(client, deployer);

    console.log(
      `========================== SINGLETONS ===========================`,
    );
    console.log("safeProxyFactoryAddress: " + safeProxyFactoryAddress);
    console.log("safeMastercopyAddress: " + safeMastercopyAddress);
    console.log("safeMultiSendAddress: " + safeMultiSendAddress);
    console.log(
      "safeMultiSendCallOnlyAddress: " + safeMultiSendCallOnlyAddress,
    );
    console.log("safeFallbackHandlerAddress: " + safeFallbackHandlerAddress);
    console.log("safeSignMessageLibAddress: " + safeSignMessageLibAddress);
    console.log("safeCreateCallAddress: " + safeCreateCallAddress);
    console.log(
      "safeSimulateTxAccessorAddress: " + safeSimulateTxAccessorAddress,
    );
    console.log(`============================================================`);
  },
);

const config: HardhatUserConfig = {
  solidity: "0.8.24",
};

export default config;
