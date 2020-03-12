const rocketh = require('rocketh');
const ethers = require('ethers');
const {
    Contract,
} = ethers;
const {
    namedAccounts,
    getDeployedContract,
} = rocketh;

const deploy_sand = require('../../stages/010_deploy_sand');
const deploy_land = require('../../stages/040_deploy_land');
const deploy_estate = require('../../stages/050_deploy_estate');
const set_estate = require('../../stages/809_set_estate');
const set_land_admin = require('../../stages/903_set_land_admin');

const {runERC721tests} = require('../batteries/erc721_tests');

const {
    deployer,
    landAdmin,
} = namedAccounts;

const {
    ethersProvider
} = require('../utils');

function ERC721Contract() {
    this.counter = 0;
    this.contract = null;
    this.contractName = 'Estate';
    this.minter = deployer;
    this.supportsBatchTransfer = true;
    this.supportsSafeBatchTransfer = true;
    this.supportsMandatoryERC721Receiver = true;
}
ERC721Contract.prototype.resetContract = async function () {
    // await rocketh.runStages();
    rocketh.resetDeployments();
    await deploy_sand(rocketh);
    await deploy_land(rocketh);
    await deploy_estate(rocketh);
    await set_estate(rocketh);
    await set_land_admin(rocketh);

    const contract = getDeployedContract(this.contractName);
    this.contract = new Contract(contract.address, contract.abi, ethersProvider);

    const landContract = getDeployedContract('Land');
    this.landContract = new Contract(landContract.address, landContract.abi, ethersProvider);
    const tx = await this.landContract.connect(ethersProvider.getSigner(landAdmin)).functions.setMinter(this.minter, true);
    await tx.wait();
    return this.contract;
};
ERC721Contract.prototype.mintERC721 = async function (creator) {
    this.counter++;
    const landTx = await this.landContract.connect(ethersProvider.getSigner(this.minter)).functions.mintQuad(creator, 1, this.counter, this.counter, '0x');
    await landTx.wait();
    const tx = await this.contract.connect(ethersProvider.getSigner(creator)).functions.createFromQuad(creator, creator, 1, this.counter, this.counter);
    const receipt = await tx.wait();
    return receipt.events.find((v) => v.event === 'QuadsAddedInEstate').args[0];
};
// ERC721Contract.prototype.burnERC721 = async function (from, tokenId) {
//     const tx = await this.contract.connect(ethersProvider.getSigner(from)).functions.burnFrom(from, tokenId);
//     return tx.wait();
// };

const factory = new ERC721Contract();
runERC721tests(factory);