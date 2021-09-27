const NeoPreemo = artifacts.require("NeoPreemo");
const NeoPreemoSale = artifacts.require("NeoPreemoSale");
const NeoPreemoAuction = artifacts.require("NeoPreemoAuction");

module.exports = async function (deployer) {
  // Please specify platform wallet address here
  const platformWallet = "";
  console.log("Start deploying NeoPreemo");
  await deployer.deploy(NeoPreemo);
  const NeoPreemoDeployed = await NeoPreemo.deployed();
  console.log("Token Contract Deployed:", NeoPreemoDeployed.address);

  console.log("Start deploying NeoPreemoSale");
  await deployer.deploy(NeoPreemoSale, NeoPreemoDeployed.address, platformWallet);
  const NeoPreemoSaleDeployed = await NeoPreemoSale.deployed();
  console.log("Sale Contract Deployed:", NeoPreemoSaleDeployed.address);

  console.log("Start deploying NeoPreemoAuction");
  await deployer.deploy(NeoPreemoAuction, NeoPreemoDeployed.address, platformWallet);
  const NeoPreemoAuctionDeployed = await NeoPreemoAuction.deployed();
  console.log("Auction Contract Deployed:", NeoPreemoAuctionDeployed.address);
  
  console.log("Add Sale contract as creator");
  await NeoPreemoDeployed.addCreator(NeoPreemoSaleDeployed.address);
  
  console.log("Add Auction contract as creator");
  await NeoPreemoDeployed.addCreator(NeoPreemoAuctionDeployed.address);
};
