import {GIVpower__factory} from "../typechain-types";

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { ethers, upgrades } = require("hardhat");

const GARDEN_UNIPOOL_ADDRESS = "0x898Baa558A401e59Cb2aA77bb8b2D89978Cf506F";

async function main() {
    const GIVPower = await ethers.getContractFactory(
        "GIVpower",
    ) as GIVpower__factory;
    const upgradedGardenUnipool = await upgrades.upgradeProxy(
        GARDEN_UNIPOOL_ADDRESS,
        GIVPower,
        {
            unsafeAllowRenames: true,
        }
    );
}

main();
