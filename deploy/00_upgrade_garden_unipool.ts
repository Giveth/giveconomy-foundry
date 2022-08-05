import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {Contract} from "ethers";
import {impersonateAddress} from "../test/helpers/rpc";
import {getImplementationAddress} from "@openzeppelin/upgrades-core";
import {GIVpower__factory} from "../typechain-types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    // code here
    const {ethers, upgrades} = hre;
    let signer;
    signer = (await ethers.getSigners())[0];
    const gardenUnipoolProxyAdminAddress = '0x076C250700D210e6cf8A27D1EB1Fd754FB487986';
    const gardenUnipoolAddress = '0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2';

    const gardenUnipoolProxyAdmin = new Contract(
        gardenUnipoolProxyAdminAddress,
        ['function owner() public view returns (address)'],
        signer
    );

    signer = await impersonateAddress(await gardenUnipoolProxyAdmin.owner());
    console.log('implementation address: ', await getImplementationAddress(ethers.provider, gardenUnipoolAddress));

    const GIVPower = (await ethers.getContractFactory('GIVpower', signer)) as GIVpower__factory;

    await upgrades.upgradeProxy(gardenUnipoolAddress, GIVPower, {
        unsafeAllowRenames: true,
    });

    console.log('new implementation address: ', await getImplementationAddress(ethers.provider, gardenUnipoolAddress));


};
export default func;

func.tags = ['UpgradeUnipool']
