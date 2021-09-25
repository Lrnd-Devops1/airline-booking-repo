const express = require('express');
const app = express();
const bodyparser = require('body-parser');
const { deploy, read, bookTicket, claim, getTicketDetails, cancelTicket, collectMoney } = require('./contract');
const config = require("./config.json");
app.use(bodyparser.json());
const deployedContracts = [];
const bookedTickets = [];
app.post("/deploy", async (req, res) => {
    let privateKey = req.body.privateKey;
    let result = await deploy(privateKey);
    res.send(result);
});

app.post("/deployFlight", async (req, res) => {
    console.log("Deploying contract");
    let account = config.accounts.filter(x => x.name === req.body.account)[0];
    let privateKey = account.privateKey;
    let flightNumber = req.body.flightNumber;
    let scheduledTime = req.body.flightTime;
    let date = (new Date(scheduledTime)).getTime();
    let unixTimestamp = date / 1000;
    let flModel = req.body.flightModel;
    console.log(unixTimestamp);
    let result = await deploy(privateKey, flightNumber, unixTimestamp, flModel);
    let contract = {
        flightNumber: flightNumber,
        scheduledTime: scheduledTime,
        flModel: flModel,
        contractAddress: result.contractAddress,
        blockHash: result.blockHash,
        status: result.status,
        transactionHash: result.transactionHash
    };
    deployedContracts.push(contract);
    console.log("Contract deployed");
    res.send(result);
});
app.post("/bookTicket", async (req, res) => {
    let seatCategory = req.body.seatCategory;
    //seatCategory = config.seatCategory.filter(x =>  x.name == seatCategory)[0];
    let account = config.accounts.filter(x => x.name === req.body.account)[0];
    let flightId = req.body.flightNumber;
    let contract = deployedContracts.filter(x => x.flightNumber == flightId)[0];
    seatCategory = config.planeModels.filter(x => x.code == contract.flModel)[0].seatCategory.filter(x => x.name == seatCategory)[0];
    //console.log(contractAddress);
    let result = await bookTicket(account.privateKey, contract.contractAddress, seatCategory.value, seatCategory.cost);
    bookedTickets.push({ "confirmationId": result.confirmationId, "flightContract": contract.contractAddress, "ticketContract": result.ticketContract });
    console.log(`Ticket booked: ${result.confirmationId}`);
    res.send(result);
});


app.get("/read", async (req, res) => {
    let flNum = req.query.flightNumber;
    console.log(flNum);
    let contractAddress = deployedContracts.filter(x => x.flightNumber == flNum)[0].contractAddress;
    let result = await read(contractAddress);
    result.flStatus = config.flightStatus.filter(x => x.value == result.flStatus)[0].name;
    result.flightTimeRaw = result.flightTime;
    result.flightTime = new Date(result.flightTime * 1000);

    result.flStatusUpdateTime = new Date(result.flStatusUpdateTime * 1000);
    res.send(result);
});

app.get("/ticketDetails", async (req, res) => {
    let confirmationId = req.body.confirmationId;
    let account = config.accounts.filter(x => x.name === req.body.account)[0];
    if (bookedTickets.length > 0) {
        let contractAddress = bookedTickets.filter(x => x.confirmationId == confirmationId)[0].flightContract;
        let ticketContract = bookedTickets.filter(x => x.confirmationId == confirmationId)[0].ticketContract;
        let result = await getTicketDetails(account.privateKey, contractAddress, confirmationId, ticketContract);
        res.send(result);
    }
});

app.post("/cancelTicket", async (req, res) => {
    let confirmationId = req.body.confirmationId;
    let account = config.accounts.filter(x => x.name === req.body.account)[0];
    let gas = req.body.gas;
    let result = "Ticket not found";
    if (bookedTickets.length > 0) {
        let removeIndex = -1;
        for (let index = 0; index < bookedTickets.length; index++) {
            const ticket = bookedTickets[index];
            if (ticket.confirmationId === confirmationId) {
                result = await cancelTicket(account.privateKey, ticket.flightContract, confirmationId, gas);
                removeIndex = index;
                break;
            }
        }
        console.log(`Ticket cancelled: ${confirmationId}`);
        bookedTickets.splice(removeIndex, 1);
    }
    res.send(result);
});

app.get("/claim", async (req, res) => {
    let confirmationId = req.body.confirmationId;
    let account = config.accounts.filter(x => x.name === req.body.account)[0];
    let result = "Ticket not found";
    if (bookedTickets.length > 0) {
        let removeIndex = -1;
        for (let index = 0; index < bookedTickets.length; index++) {
            const ticket = bookedTickets[index];
            if (ticket.confirmationId === confirmationId) {
                let contractAddress = ticket.flightContract;
                result = await claim(account.privateKey, contractAddress, confirmationId);
                removeIndex = index;
                break;
            }
        }
        bookedTickets.splice(removeIndex, 1);
    }
    res.send(result);
});

app.get("/collectMoney", async (req, res) => {
    let confirmationId = req.body.confirmationId;
    let account = config.accounts.filter(x => x.name === req.body.account)[0];
    let result = "Ticket not found";
    if (bookedTickets.length > 0) {
        let removeIndex = -1;
        for (let index = 0; index < bookedTickets.length; index++) {
            const ticket = bookedTickets[index];
            if (ticket.confirmationId === confirmationId) {
                let contractAddress = ticket.flightContract;
                result = await collectMoney(account.privateKey, contractAddress, confirmationId);
                removeIndex = index;
                break;
            }
        }
        bookedTickets.splice(removeIndex, 1);
    }
    res.send(result);
});

app.listen(4000, () => {
    console.log("server started");
});