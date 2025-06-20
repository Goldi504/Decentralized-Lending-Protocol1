const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Decentralized Lending Protocol...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());

  // Deploy the main contract
  const Project = await ethers.getContractFactory("Project");
  const project = await Project.deploy();
  
  await project.waitForDeployment();
  const projectAddress = await project.getAddress();
  
  console.log("Project contract deployed to:", projectAddress);

  // Deploy a mock ERC20 token for testing
  const MockToken = await ethers.getContractFactory("MockERC20");
  const mockToken = await MockToken.deploy("Mock USDC", "MUSDC", 6);
  
  await mockToken.waitForDeployment();
  const mockTokenAddress = await mockToken.getAddress();
  
  console.log("Mock Token deployed to:", mockTokenAddress);

  // Add the mock token to the lending protocol
  const interestRate = 500; // 5% annual interest rate
  const collateralRatio = 15000; // 150% collateral ratio
  
  const addTokenTx = await project.addSupportedToken(mockTokenAddress, interestRate, collateralRatio);
  await addTokenTx.wait();
  
  console.log("Mock token added to lending protocol");

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    projectContract: projectAddress,
    mockToken: mockTokenAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString()
  };

  console.log("Deployment completed successfully!");
  console.log("Deployment Info:", deploymentInfo);
  
  return { project, mockToken, deployer };
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

module.exports = main;
