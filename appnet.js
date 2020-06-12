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
    TransactionReceipt,
    AccountInfoQuery
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

const client = Client.forTestnet();
client.setOperator(operatorAccount, operatorPrivateKey);

let owner;
let users = [];
let args = process.argv;

let constructor = () => {
    owner = new User(operatorAccount, initSupply, []);

    let memo = {
        name : name,
        symbol : symbol,
        initsupply : initSupply,
        owner : owner.address
    }

    let transactionId = new ConsensusTopicCreateTransaction()
        .setTopicMemo(JSON.stringify(memo))
        .setMaxTransactionFee(100000000000)
    
    transactionId.execute(client).catch(console.log).then((r) => {
        r.getReceipt(client).catch(console.log).then((res) => {
            console.log(res);
            let topicId = res.getConsensusTopicId();
            //let hash = res.get
            console.log(topicId);
            let fileName = topicId + ".json";
            let topicJson = {
                topic : topicId,
                name : name,
                symbol : symbol,
                initsupply : initSupply,
                owner : owner.address,
                users : [owner],
                currentMXUSDPrice : 100,
                currentMXHbarPrice : 0,
                currentHbarUSDPrice : 0,
                consensushash : []
            }
            fs.writeFile(fileName, JSON.stringify(topicJson), (err) => {
                if(err) console.log(err);
            });

            new ConsensusMessageSubmitTransaction()
                .setTopicId(topicId)
                .setMessage(JSON.stringify(topicJson))
                .execute(client);
        });
    });
}

const topicId = new ConsensusTopicId(0, 0, args[3]);
const topicFile = "0.0." + args[3] + ".json";

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
let latestHash = "0x00";

function User(address, balance, allowance) {
    this.address = address;
    this.balance = balance;
    this.allowance = allowance;
    this.approve = function(to, sum, myId) {
        checkUser(to, (err, res) => {
            if(!err) {
				let type = "approve",
				let txHash = crypto.createHash('sha512').update(type + this.address + to + sum.toString()).digest('hex');
				let hash = crypto.createHash('sha512').update(latestHash.toString()+txHash.toString()).digest('hex');
				console.log(latestHash, txHash, hash);
				let message = {
					type : type,
					fromAddress : this.address,
					toAddress : to,
					amount : sum,
					txHash : txHash,
					hash : hash
				};
				new ConsensusMessageSubmitTransaction()
		            .setTopicId(topicId)
		            .setMessage(JSON.stringify(message))
		            .execute(client);
            } else {
                console.log(err);
            }
        });
    };
    this.transfer = function(to, sum, myId) {
        checkUser(to, (err, res) => {
            if(!err) {
				let type = "transfer";
				let	fromPreviousBalance = res[1].users[myId].balance;
				let	toPreviousBalance = res[1].users[res[2]].balance;
				let	fromCurrentBalance = res[1].users[myId].balance -= sum;
                let	toCurrentBalance = res[1].users[res[2]].balance += sum;
				let txHash = crypto.createHash('sha512').update(type + this.address + to + fromPreviousBalance.toString() + toPreviousBalance.toString() + sum.toString() + fromCurrentBalance.toString() + toCurrentBalance.toString()).digest('hex');
				let hash = crypto.createHash('sha512').update(latestHash.toString()+txHash.toString()).digest('hex');
				console.log(latestHash, txHash, hash);
				let message = {
					type : type,
					fromAddress : this.address,
					toAddress : to,
					fromPreviousBalance : fromPreviousBalance,
					toPreviousBalance : toPreviousBalance,
					amount : sum,
					fromCurrentBalance : fromCurrentBalance,
                	toCurrentBalance : toCurrentBalance,
					txHash : txHash,
					hash : hash
				};
				
				new ConsensusMessageSubmitTransaction()
		            .setTopicId(topicId)
		            .setMessage(JSON.stringify(message))
		            .execute(client);
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

switch(args[2]) {
    case 'transfer' : transfer(args[4], args[5]);
        break;
    case 'approve' : approve(args[4], args[5]);
        break;
    case 'constructor' : constructor();
        break;
    default : console.log("MISSING ARGS!");
}





