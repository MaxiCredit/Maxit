const {
    Client,
    MirrorClient,
    MirrorConsensusTopicQuery,
    ConsensusTopicCreateTransaction,
    Ed25519PublicKey,
    Ed25519PrivateKey,
    ConsensusMessageSubmitTransaction,
    ConsensusTopicId
    ConsensusTopicInfoQuery,
    TransactionId,
    TransactionReceipt
} = require("@hashgraph/sdk");
require("dotenv").config();
const crypto = require('crypto');
const fs = require('fs');

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

new MirrorConsensusTopicQuery()
    .setTopicId(topicId)
    .setStartTime(1590000000)
    .subscribe( 
        consensusClient,
        (res) => {
            console.log(res.sequenceNumber);
            let str = String.fromCharCode.apply(null, res.message);
            console.log(str);
    });
