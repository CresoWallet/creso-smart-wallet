import { deployments, ethers } from 'hardhat'
import { ENTRY_POINT_ADDRESS } from '../constant';

async function main() {

  // Deploy the CresoWallet implementation
  const CresoWalletFactory = await ethers.getContractFactory("CresoWalletFactory");
  const CresoWalletFactory = await CresoWalletFactory.deploy(ENTRY_POINT_ADDRESS);
  await CresoWalletFactory.deployed();
  console.log("CresoWalletFactory deployed to:", CresoWalletFactory.address);


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });