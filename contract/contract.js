const Web3 = require('web3');
const EEAClient = require('web3-eea');
const url = "http://bootnode:8545"
const chainId = 1337
const web3 = new EEAClient(new Web3(new Web3.providers.HttpProvider(url)), chainId);

const Tx = require("ethereumjs-tx").Transaction;
const Common = require("ethereumjs-common");

const contract = require("./contract.json");
const config = require("./config.json");

exports.deploy = (privateKey, flNum, flTime, flModel) => {
    let besuAccount = web3.eth.accounts.privateKeyToAccount(`0x${privateKey}`);
    let bytecodeWithParameters = web3.eth.abi.encodeParameters(["string flNum", "uint256 flTime", "string flModel"], [flNum, flTime, flModel]).slice(2);
    console(besuAccount);
    return web3.eth.getTransactionCount(besuAccount.address, "pending").then(async (txCount) => {
        let gasPrice = await web3.eth.getGasPrice();
        console.log(txCount);
        const txObj = {
            nonce: web3.utils.toHex(txCount),
            gasPrice: web3.utils.toHex(47000),
            gasLimit: web3.utils.toHex(8000000),
            data: '0x' + contract.bytecode + bytecodeWithParameters,
            chainId: chainId
        };
        let custom = Common.default.forCustomChain("mainnet", {
            networkId: 123,
            chainId: chainId,
            name: "besu-network"
        }, "istanbul");

        let tx = new Tx(txObj, { common: custom });
        let private = Buffer.from(privateKey, "hex");
        tx.sign(private);
        let serialized = tx.serialize();
        let rawSerialized = "0x" + serialized.toString("hex");

        return web3.eth.sendSignedTransaction(rawSerialized)
            .on("receipt", receipt => {//console.log(receipt)
            })
            .catch(error => console.log(error));
    })
}

exports.bookTicket = async (privateKey, contractAddress, value, cost) => {
    let besuAccount = web3.eth.accounts.privateKeyToAccount(`0x${privateKey}`);
    let contractInstance = new web3.eth.Contract(contract.abi, contractAddress);

    let encoded = contractInstance.methods.bookSeat(value).encodeABI();

    return web3.eth.getTransactionCount(besuAccount.address, "pending").then(async (txCount) => {
        let gasPrice = await web3.eth.getGasPrice();
        const txObj = {
            nonce: web3.utils.toHex(txCount),
            gasPrice: web3.utils.toHex(4000000),
            gasLimit: web3.utils.toHex(10000000),
            data: encoded,
            chainId: chainId,
            to: contractAddress,
            value: cost
        };
        let custom = Common.default.forCustomChain("mainnet", {
            networkId: 123,
            chainId: chainId,
            name: "besu-network"
        }, "istanbul");
        let tx = new Tx(txObj, { common: custom });

        let private = Buffer.from(privateKey, "hex");
        tx.sign(private);
        let serialized = tx.serialize();
        let rawSerialized = "0x" + serialized.toString("hex");

        let result = await web3.eth.sendSignedTransaction(rawSerialized);
        result.confirmationId = await web3.eth.abi.decodeLog([{
            "internalType": "string",
            "name": "",
            "type": "string"
        }], result.logs[0].data)["0"];
        result.ticketContract = result.logs[0].address;
        return result;
    })
}

exports.read = async (contractAddress) => {
    let contractInstance = new web3.eth.Contract(contract.abi, contractAddress);
    let flNum = await contractInstance.methods.flightNumber().call().then(value => { return value });
    let flStatus = await contractInstance.methods.flightStatus().call().then(value => { return value });
    let flStatusUpdateTime = await contractInstance.methods.flightStatusUpdateTime().call().then(value => { return value });
    let flightTime = await contractInstance.methods.flightTime().call().then(value => { return value });
    let fModel = await contractInstance.methods.model().call().then(value => { return value });
    let eseats = await contractInstance.methods.seats(0).call().then(value => { return value });
    let peseats = await contractInstance.methods.seats(1).call().then(value => { return value });
    let bcseats = await contractInstance.methods.seats(2).call().then(value => { return value });
    let fcseats = await contractInstance.methods.seats(3).call().then(value => { return value });
    return {
        "flNum": flNum,
        "flStatus": flStatus,
        "flStatusUpdateTime": flStatusUpdateTime,
        "flightTime": flightTime,
        "fModel": fModel,
        "available seats": `Economy: ${eseats}| Premium Economy: ${peseats}| Business: ${bcseats}| First class: ${fcseats}`
    };
}

exports.getTicketDetails = async (privateKey, contractAddress, confirmationId, ticketContract) => {
    let besuAccount = web3.eth.accounts.privateKeyToAccount(`0x${privateKey}`);
    let contractInstance = new web3.eth.Contract(contract.abi, contractAddress);

    ticketContract = await contractInstance.methods.getTicketFromID(confirmationId).call().then(value => { return value });
    console.log(ticketContract);
    let ticketContractInstance = new web3.eth.Contract(contract.ticketAbi, ticketContract, { from: besuAccount.address, gas: web3.utils.toHex(10000000) });
    console.log(ticketContractInstance);
    let status = await ticketContractInstance.methods.cancelled().call({ from: besuAccount.address }).then(value => { return value });
    let seatCategory = await ticketContractInstance.methods.seatCategory().call({ from: besuAccount.address }).then(value => { return value });
    let ticketDetails = {
        "airline": "",
        "bookingReference": confirmationId,
        "status": status === false ? "Booked" : "Cancelled",
        "class": config.seatCategory.filter(x => x.value == seatCategory)[0].name
    }
    return ticketDetails;
}

exports.cancelTicket = async (privateKey, contractAddress, confirmationId, gas) => {
    let besuAccount = web3.eth.accounts.privateKeyToAccount(`0x${privateKey}`);
    let contractInstance = new web3.eth.Contract(contract.abi, contractAddress);

    let ticketContract = await contractInstance.methods.getTicketFromID(confirmationId).call().then(value => { return value });
    let ticketContractInstance = new web3.eth.Contract(contract.ticketAbi, ticketContract, { from: besuAccount.address });
    let encoded = await ticketContractInstance.methods.cancel().encodeABI();
    // let encoded = ticketMethod.encodeABI();
    return web3.eth.getTransactionCount(besuAccount.address, "pending").then(async (txCount) => {
        console.log(txCount);
        const txObj = {
            nonce: web3.utils.toHex(txCount),
            data: encoded,
            gas: web3.utils.toHex(10000000),
            from: besuAccount.address,
            to: ticketContract
        };
        let signed = await web3.eth.accounts.signTransaction(txObj, `0x${privateKey}`);

        let result = await web3.eth.sendSignedTransaction(signed.rawTransaction)
            .on("receipt", receipt => { console.log(receipt) })
            .catch(error => console.log(error));

        return result;
    });

}

exports.claim = async (privateKey, contractAddress, confirmationId) => {
    let besuAccount = web3.eth.accounts.privateKeyToAccount(`0x${privateKey}`);
    let contractInstance = new web3.eth.Contract(contract.abi, contractAddress);

    let ticketContract = contractInstance.methods.getTicketFromID(confirmationId).call().then(value => { return value });
    let ticketContractInstance = new web3.eth.Contract(contract.ticketAbi, ticketContract, { from: besuAccount.address });
    let encoded = await ticketContractInstance.methods.claim().encodeABI();
    return web3.eth.getTransactionCount(besuAccount.address, "pending").then(async (txCount) => {
        console.log(txCount);
        const txObj = {
            nonce: web3.utils.toHex(txCount),
            data: encoded,
            gas: web3.utils.toHex(10000000),
            from: besuAccount.address,
            to: ticketContract
        };
        let signed = await web3.eth.accounts.signTransaction(txObj, `0x${privateKey}`);

        let result = await web3.eth.sendSignedTransaction(signed.rawTransaction)
            .on("receipt", receipt => { console.log(receipt) })
            .catch(error => console.log(error));

        return result;
    });
}

exports.collectMoney = async (privateKey, contractAddress, confirmationId) => {
    let besuAccount = web3.eth.accounts.privateKeyToAccount(`0x${privateKey}`);
    let contractInstance = new web3.eth.Contract(contract.abi, contractAddress);

    let ticketContract = contractInstance.methods.getTicketFromID(confirmationId).call().then(value => { return value });
    let ticketContractInstance = new web3.eth.Contract(contract.ticketAbi, ticketContract, { from: besuAccount.address });
    let encoded = await ticketContractInstance.methods.collectMoney().encodeABI();
    return web3.eth.getTransactionCount(besuAccount.address, "pending").then(async (txCount) => {
        console.log(txCount);
        const txObj = {
            nonce: web3.utils.toHex(txCount),
            data: encoded,
            gas: web3.utils.toHex(10000000),
            from: besuAccount.address,
            to: ticketContract
        };
        let signed = await web3.eth.accounts.signTransaction(txObj, `0x${privateKey}`);

        let result = await web3.eth.sendSignedTransaction(signed.rawTransaction)
            .on("receipt", receipt => { console.log(receipt) })
            .catch(error => console.log(error));

        return result;
    });
}