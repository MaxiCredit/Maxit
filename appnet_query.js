const {
    Client,
    MirrorClient,
    MirrorConsensusTopicQuery,
    ConsensusTopicCreateTransaction,
    Ed25519PublicKey,
    Ed25519PrivateKey,
    ConsensusMessageSubmitTransaction,
    ConsensusTopicId,
    ConsensusTopicInfoQuery,
    TransactionId,
    TransactionReceipt
} = require("@hashgraph/sdk");
require("dotenv").config();
const crypto = require('crypto');
const fs = require('fs');

const symbol = "MX_v0.1";
const name = "Maxit_test_0.1";
const initSupply = 1000000;

const operatorPrivateKey = Ed25519PrivateKey.fromString(process.env.PRIVATE_KEY);
const operatorAccount = process.env.ACCOUNT_ID;
const mirrorNodeAddress = process.env.MIRROR_NODE_ADDRESS;
const nodeAddress = process.env.NODE_ADDRESS;

if (operatorPrivateKey == null ||
    operatorAccount == null ||
    mirrorNodeAddress == null ||
    nodeAddress == null) {
    throw new Error("environment variables OPERATOR_KEY, OPERATOR_ID, MIRROR_NODE_ADDRESS, NODE_ADDRESS must be present");
}

const consensusClient = new MirrorClient(mirrorNodeAddress);
const client = Client.forTestnet();
client.setOperator(operatorAccount, operatorPrivateKey);

let owner;
let users = [];
let args = process.argv;

let topicId = new ConsensusTopicId(0, 0, args[2]);
const topicFile = "0.0." + args[2] + ".json";

let checkUser = (address, callback) => {
    //check address on hedera
	console.log(address);
    let hederaCheck = new AccountInfoQuery()
        .setAccountId(address);

    hederaCheck.execute(client).catch((e) => {
        console.log(e.status);
        callback(e.status, null);
    }).then((r) => {
        if(r) {
            let recipient = {};
            
            fs.readFile(topicFile, (err, data) => {
                if(!err) {
                    let json = JSON.parse(data);
                    users = json.users;
                    //console.log(users, users.length);
                    let i = 0;
                    let id;
                    while(i < users.length) {
                        //console.log("Counter:", i);
                        if(users[i].address == address) {
                            recipient = users[i];
                            //console.log("Talált:", recipient);
                            id = i;
                            i = users.length;         
                        } else {
                            if(i == users.length - 1) {
                                recipient = new User(address, 0, []);
                                json.users.push(recipient);
                                fs.writeFile(topicFile, JSON.stringify(json), (error) => {
                                    if(error) console.log(error);
                                });
                                id = i;
                            }
                            i ++;
                        }
                    }
                    callback(null, [recipient, json, id]);          
                } else {
                    console.log(err);
                    callback(err, null);
                }
            });   
        }
    });
}

function User(address, balance, allowance) {
    this.address = address;
    this.balance = balance;
    this.allowance = allowance;
    this.approve = function(to, sum, myId) {
        checkUser(to, (err, res) => {
            if(!err) {
                let allowanceCount = res[1].users[myId].allowance.length;
                let y = 0;
                while(y < allowanceCount) {
                    console.log(res[1].users[myId].allowance[y][0], res[1].users[myId].allowance[y][1]);
                    if(to == res[1].users[myId].allowance[y][0]) {
                        res[1].users[myId].allowance[y][1] += sum;
                        y = allowanceCount;
                    } else {
                        if(y == allowanceCount - 1) {
                            res[1].users[myId].allowance.push([to, sum]);
                        }
                        y ++;
                    }
                } 
				//check with topic message               
                fs.writeFile(topicFile, JSON.stringify(res[1]), (err) => {
                    if(err) console.log(err);
                });
            } else {
                console.log(err);
            }
        });
    };
    this.transfer = function(to, sum, myId) {
        checkUser(to, (err, res) => {
            if(!err) {
                res[1].users[myId].balance -= sum;
                res[1].users[res[2]].balance += sum;
				//check with topic message
                fs.writeFile(topicFile, JSON.stringify(res[1]), (err) => {
                    if(err) console.log(err);
                });
            } else {
                console.log(err);
            }
        });
    };
}

let transfer = (to, sum) => {
    checkUser(operatorAccount, (err, res) => {
        if(!err) {
            let currentUser = new User(res[0].address, res[0].balance, res[0].allowance);
            currentUser.transfer(to, parseInt(sum), res[2]);
            //console.log(res);
        } else {
            console.log("Transfer error:", err);
        }
    });
}

let approve = (to, sum) => {
    checkUser(operatorAccount, (err, res) => {
        if(!err) {
            let currentUser = new User(res[0].address, res[0].balance, res[0].allowance);
            currentUser.approve(to, parseInt(sum), res[2]);
            //console.log(res);
        } else {
            console.log("Approve:", err);
        }
    });
}

new MirrorConsensusTopicQuery()
    .setTopicId(topicId)
    .setStartTime(1590000000)
        //.setEndTime(1592000000)
    .subscribe( 
        consensusClient,
        (res) => {
            console.log(res.sequenceNumber);
            let str = String.fromCharCode.apply(null, res.message);
            console.log(str);
			let message = JSON.parse(str);
			console.log(message.type);

			switch(message.type) {
				case 'approve' : approve(message.toAddress, message.amount);
					break;
				case 'transfer' : transfer(message.toAddress, message.amount);
					break;
				default : console.log("No such function!");
			}
    });
