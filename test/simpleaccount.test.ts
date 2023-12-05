import { expect } from "chai";
import { ethers, waffle } from "hardhat";
import { Contract } from "ethers";

describe("CresoWalletFactory", function () {
  let CresoWalletFactory: any;
  let CresoWalletImplementation: Contract;
  let CresoWalletGuard: Contract;
  let entryPoint: Contract;
  let owner: any;
  let guardian1: any;
  let nonGuardian: any;
  let salt: string;

  before(async function () {
    [owner, guardian1,nonGuardian] = await ethers.getSigners();
    salt = ethers.utils.id("0");

    // Deploy EntryPoint mock if needed and set it up
    // Assume `EntryPointMock` is a mock contract for testing purposes
    const EntryPointMock = await ethers.getContractFactory("EntryPoint");
    entryPoint = await EntryPointMock.deploy();
    await entryPoint.deployed();

    // Deploy CresoWallet implementation
    const CresoWallet = await ethers.getContractFactory("CresoWallet");
    CresoWalletImplementation = await CresoWallet.deploy(entryPoint.address);
    await CresoWalletImplementation.deployed();

    // Deploy the CresoWalletFactory with the entry point and the implementation
    CresoWalletFactory = await ethers.getContractFactory("CresoWalletFactory");
    CresoWalletFactory = await CresoWalletFactory.deploy(entryPoint.address);
    await CresoWalletFactory.deployed();

    CresoWalletGuard = new ethers.Contract(
      await CresoWalletFactory.getAddress(owner.address, salt),
      CresoWalletImplementation.interface,
      owner
    );

  });

  it("Should compute the correct wallet address", async function () {
    const computedAddress = await CresoWalletFactory.getAddress(owner.address, salt);
    console.log("computedAddress: " + computedAddress)
    expect(computedAddress).to.be.properAddress;
  });

  it("Should create a wallet", async function () {
    const tx = await CresoWalletFactory.createAccount(owner.address, salt);
    const receipt = await tx.wait();
    const CresoWalletAddress = await CresoWalletFactory.getAddress(owner.address, salt);

    // Instead of checking for the event, check if the contract has code
    const codeSize = await ethers.provider.getCode(CresoWalletAddress);
    expect(codeSize).to.not.equal("0x", "Expected contract to have code, but it does not");
  });

  it("Should transfer ethers to the wallet", async function () {
    const CresoWalletAddress = await CresoWalletFactory.getAddress(owner.address, salt);
    const transferAmount = ethers.utils.parseEther("1");

    // Use Waffle's provider to send ethers to the wallet address
    await owner.sendTransaction({
      to: CresoWalletAddress,
      value: transferAmount,
    });

    // Check balance of the wallet
    const provider = waffle.provider;
    const balance = await provider.getBalance(CresoWalletAddress);
    expect(balance).to.equal(transferAmount);
  });

  it("Should execute a transaction from the wallet", async function () {
    const CresoWalletAddress = await CresoWalletFactory.getAddress(owner.address, salt);
    const CresoWallet = new ethers.Contract(
      CresoWalletAddress,
      CresoWalletImplementation.interface,
      owner
    );

    const recipient = ethers.Wallet.createRandom();
    const transferAmount = ethers.utils.parseEther("0.5");

    // Execute transaction from the wallet to the recipient
    await CresoWallet.execute(recipient.address, transferAmount, []);

    // Check balance of the recipient
    const provider = waffle.provider;
    const balance = await provider.getBalance(recipient.address);
    expect(balance).to.equal(transferAmount);
  });


  it("Should add a guardian successfully", async function () {
    await expect(CresoWalletGuard.addGuardian(guardian1.address))
      .to.emit(CresoWalletGuard, "GuardianAdded")
      .withArgs(guardian1.address);

    // Verify the added guardian
    const isGuardianAdded = await CresoWalletGuard.isGuardian(guardian1.address);
    expect(isGuardianAdded).to.be.true;
  });

  it("Should remove a guardian successfully", async function () {
    await expect(CresoWalletGuard.removeGuardian(guardian1.address))
      .to.emit(CresoWalletGuard, "GuardianRemoved")
      .withArgs(guardian1.address);
  
    // Verify the guardian was removed
    const isGuardian = await CresoWalletGuard.isGuardian(guardian1.address);
    expect(isGuardian).to.be.false;
  });
  
  it("Should prevent removing a non-guardian", async function () {
    await expect(CresoWalletGuard.removeGuardian(nonGuardian.address))
      .to.be.revertedWith("Not a guardian");
  });
  
  it("Should initiate recovery process by a guardian", async function () {
    await CresoWalletGuard.addGuardian(guardian1.address);
    await expect(CresoWalletGuard.connect(guardian1).startRecovery(nonGuardian.address))
      .to.emit(CresoWalletGuard, "RecoveryStarted")
      .withArgs(nonGuardian.address);
  
    // Verify recovery state
    expect(await CresoWalletGuard.recoveryActive()).to.be.true;
    expect(await CresoWalletGuard.proposedNewOwner()).to.equal(nonGuardian.address);
  });
  
  it("Should confirm recovery by a guardian after time lock", async function () {
    await ethers.provider.send("evm_increaseTime", [24 * 60 * 60 + 1]); // 24 hours + 1 second
    await ethers.provider.send("evm_mine", []);
  
    await expect(CresoWalletGuard.connect(guardian1).confirmRecovery())
      .to.emit(CresoWalletGuard, "OwnerChanged")
      .withArgs(owner.address, nonGuardian.address);
  
    // Verify new owner
    expect(await CresoWalletGuard.owner()).to.equal(nonGuardian.address);
  });
  
  it("Should allow owner to cancel recovery", async function () {
    // await CresoWalletGuard.removeGuardian(guardian1.address);
    // await CresoWalletGuard.connect(nonGuardian).addGuardian(guardian1.address);
    await CresoWalletGuard.connect(guardian1).startRecovery(owner.address);
  
    await expect(CresoWalletGuard.connect(nonGuardian).cancelRecovery())
      .to.emit(CresoWalletGuard, "RecoveryCancelled")
      .withArgs(nonGuardian.address);
  
    // Verify recovery cancelled
    expect(await CresoWalletGuard.recoveryActive()).to.be.false;
  });
  
  it("Should prevent non-owner from cancelling recovery", async function () {
    await CresoWalletGuard.connect(guardian1).startRecovery(nonGuardian.address);
    await expect(CresoWalletGuard.connect(guardian1).cancelRecovery())
      .to.be.revertedWith("only owner");
  });

});

