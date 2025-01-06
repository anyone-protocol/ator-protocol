///this scripts creates a new wallet and seed it amount of tokens equal <arg3> from a wallet with private key <arg2> .
//Public key, private key and phrase of the new wallet are saved into file <arg1>
//how to run:
//npm install ethers
//node create-wallet.js wallet 0xa7b5e3f3eb7acef733a8ga48hej7aca6c2d4d750c2f3d6f737648d57227da139 0.001
const filename = process.argv.slice(2)[0];
const from_wallet_prvkey = process.argv.slice(2)[1];
const seedTokenAmount = process.argv.slice(2)[2];
console.log(filename);
console.log(from_wallet_prvkey);
console.log(seedTokenAmount);
//import

//const require = createRequire(import.meta.url);
const { ethers, JsonRpcProvider } = require('ethers');
const fs = require('fs');
//new wallet
const newWallet = ethers.Wallet.createRandom();
fs.writeFile(filename + "prv", newWallet.privateKey, (err) => { if (err) throw err; console.log('Private key saved to file'); });
fs.writeFile(filename + "pub", newWallet.address, (err) => { if (err) throw err; console.log('Public key to file'); });
fs.writeFile(filename + "mnem", newWallet.mnemonic.phrase, (err) => { if (err) throw err; console.log('Phrase saved to file'); });
//transfer
let wallet = new ethers.Wallet(from_wallet_prvkey);

// const provider = ethers.getDefaultProvider("homestead", {  
//     infura: "cfed69d3b4fd4630b1957335cdb517cb",
// });

const provider = new ethers.providers.JsonRpcProvider('https://sepolia.infura.io/v3/cfed69d3b4fd4630b1957335cdb517cb');
let signer = wallet.connect(provider);
let transaction = signer.sendTransaction({
    to: newWallet.address,
    value: ethers.utils.parseEther(seedTokenAmount)
})
fs.writeFile(filename + "trans", transaction.hash, (err) => { if (err) throw err; console.log('Transaction saved to file'); });
