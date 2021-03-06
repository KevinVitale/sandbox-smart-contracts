const {ethers} = require("@nomiclabs/buidler");

const program = require("commander");

const zeroAddress = "0x0000000000000000000000000000000000000000";

program
  .command("buy <x> <y> <size>")
  .description("buy land from presale 3")
  .option("--gasPrice <gasPrice>", "gasPrice to user")
  .option("-t, --test", "test mode")
  .action(async (x, y, size, cmdObj) => {
    const {deployer} = await getNamedAccounts();
    const sender = deployer;

    x = parseInt(x, 10);
    y = parseInt(y, 10);
    size = parseInt(size, 10);
    const landWithProofsData = fs.readFileSync("./.presale_3_proofs_1.json");
    const landWithProofs = JSON.parse(landWithProofsData);
    let landToBuy;
    for (const land of landWithProofs) {
      if (land.x === x && land.y === y && land.size === size) {
        landToBuy = land;
        break;
      }
    }
    if (!landToBuy) {
      console.error(`cannot find land ${x}, ${y}, ${size}`);
      process.exit(1);
    }
    if (!landToBuy.reserved) {
      landToBuy.reserved = zeroAddress;
    }

    const LandPreSale = await ethers.getContract("LandPreSale_3");
    const gasPrice = cmdObj.gasPrice;
    console.log({
      preSale: LandPreSale.address,
      sender,
      gasPrice,
      land: landToBuy,
    });
    console.log("PreSale Contract Address:");
    console.log(LandPreSale.address);
    console.log("------------------------------------------------");
    console.log("reserved:");
    console.log(landToBuy.reserved);
    console.log("x:");
    console.log(landToBuy.x);
    console.log("y:");
    console.log(landToBuy.y);
    console.log("size:");
    console.log(landToBuy.size);
    console.log("price:");
    console.log(landToBuy.price);
    console.log("salt:");
    console.log(landToBuy.salt);
    console.log("proof:");
    console.log(JSON.stringify(landToBuy.proof));

    // if (!cmdObj.test) {
    //     const receipt = await tx({from: sender, gas: 1000000, gasPrice}, LandPreSale, 'buyLandWithETH', sender, destination);
    //     console.log(receipt);
    // } else {
    //     console.log('was for test only');
    // }
  });

program.parse(process.argv);
