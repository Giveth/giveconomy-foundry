const BigNumber = require('bignumber.js')

const lockAmountStr = process.argv[2];
const roundsStr = process.argv[3];

const lockAmount = new BigNumber(lockAmountStr)
const rounds = new BigNumber(roundsStr);

let power = lockAmount.times(rounds.plus(1).sqrt())
power = new BigNumber(power.toFixed(0, BigNumber.ROUND_DOWN));
const powerBased16 = power.toString(16)

const result = `0x${'0'.repeat(64 - powerBased16.length)}${powerBased16}`

console.log(result)