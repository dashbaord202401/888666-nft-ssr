import pkg from "hardhat";
const { ethers } = pkg;

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("deploying contract with the account:", deployer?.address);

  const market = await ethers.deployContract("Market");
  const marketAddress = await market.getAddress();

  const NFT = await ethers.getContractFactory("NFT");
  const nft = await NFT.deploy(marketAddress);

  const nftAdress = await nft.getAddress();

  console.log({ marketAddress, nftAdress });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
