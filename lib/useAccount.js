import {AptosClient,HexString,TokenClient,CoinClient} from 'aptos';

const TEST_ADDRESS = "0xba78c665ccef66de6e6ca1fd085a9a2e3e08ef65998df3f419a555e8039f3987"
const NODE_URL = "https://fullnode.mainnet.aptoslabs.com"
let coinTypes = []
export const getResources = async (addr) => {
  const client = new AptosClient(NODE_URL);
  const res = await client.getAccountResources(
    new HexString(addr));
  // const coins = client.
  // console.log(res);
  return userResFormatted(res);
}

const userCoins = (resources) => {
  let coinTypes = []
  resources.forEach((res) => {
    if(res.type.includes("coin")){
      coinTypes.push(res.type)
    }
  })
  return coinTypes;
}

export const multipleAddrs = async (addrs) => {
  let addrsArr = []
  addrs.forEach((addr) => {
    addrsArr.push(getResources(addr))
  })
  console.log("HELP",addrsArr.length)
  return addrsArr
}

export const coinInfo = async (addr) => {
  const client = new AptosClient(NODE_URL);
  const coinClient = new CoinClient(NODE_URL);
}


export const getAccount = async (addr) => {
  // this function should get the resources, coins, and transactions for an account
  const resources = await getResources(addr);
  const userCoins = userCoins(resources);
  
  return {
    resources,
    
  }
    ;
}

export const userResFormatted = (resources) => {
  return resources.map((res) => {
  let resStr = "";
  resStr += `type: ${res.type}`;
  if(res.type.includes("coin")){
    // resStr += `\namount: ${res.amount}`;
    // resStr += `\naddress: ${res.address}`;
    if(res.data.coin){
      resStr += `\nname: ${res.data.coin.name}`;
      let decimals = res.data.coin.decimals;
      console.log(res.data.coin);
      resStr += `\namount: ${res.data.coin.value/100000000}`;
    }
    
  }
  console.log(resStr);
  return resStr;
  }).join('\n\n');
  
};