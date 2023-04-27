import generateResponse from "./lib/generateResponse.js";
import promptSync from 'prompt-sync';
import {AptosClient,HexString,TokenClient} from 'aptos';
const prompt = promptSync();
import {generateResourceResponse} from './lib/generateResponse.js';
import { request,gql } from 'graphql-request'
import {getResources,multipleAddrs,getAccount} from './lib/useAccount.js'
import {TEST_ADDRESS,NODE_URL} from './lib/constants.js'

// import {AIPluginTool} from "langchain/tools"
const conversationHistory = [];




const GET_NFTS = gql`
    query CurrentTokens($owner_address: String, $offset: Int) {
  current_token_ownerships(
    order_by: {last_transaction_version: desc}
    offset: $offset
    where: {owner_address: {_eq: $owner_address}}
  ) {
    token_data_id_hash
    name
    collection_name
    owner_address
    token_properties

    current_token_data {
      token_data_id_hash
      metadata_uri
    }

    current_collection_data {
      description
      metadata_uri
      supply
      last_transaction_timestamp
    }
  }
}`;


const req = await request(NODE_URL,
        GET_NFTS,
        { owner_address: TEST_ADDRESS, offset: 0 },
)

console.log(req.body);


// const getNfts = async (addr) => {
  

const self_addrs = ["i","I","user","my","me","self","wallet"]

const parseAddrs= (userEntry,userAddr=TEST_ADDRESS)=>{
  const words = userEntry.split(' ');
  const addrs = [];
  words.forEach((word)=>{
    if(word.includes('0x')){
    addrs.push(word);
    }
    if(self_addrs.includes(word)){
      addrs.push(userAddr);
    }
    
    
  })
  return addrs;
  
}


while (true) {
  
  const question = prompt("Generate Move Code >");

  const mentionedAddrs = parseAddrs(question);
  const userRes =await getResources(TEST_ADDRESS);
  console.log(mentionedAddrs);
  
  
  const answer = await generateResourceResponse({
    prompt: question,
    history: conversationHistory,
    context: userRes,
  });

  console.log(`MoveGPT: ${answer}\n`);
  
  conversationHistory.push(`Human: ${question}`, `MoveGPT: ${answer}`)
}