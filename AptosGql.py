NODE_URL ="https://indexer.mainnet.aptoslabs.com/v1/graphql"


import requests
from gql import gql, Client
from gql.transport.requests import RequestsHTTPTransport

GET_NFTS_OWNER = """
    query CurrentTokens($owner_address: String, $offset: Int) {
  current_token_ownerships(
    order_by: {last_transaction_version: desc}
    offset: $offset
    where: {owner_address: {_eq: $owner_address}}
  ) {
    amount
    collection_name
    creator_address
    name
    owner_address

  }
}"""

# def generic_formatter(query,variables):
#     for var in variables.keys()
    


class AptosGQLTool:
    def __init__(self, url=NODE_URL , headers=None):
        self.url = url
        self.headers = headers or {}
        self.transport = RequestsHTTPTransport(url=self.url, headers=self.headers)
        self.client = Client(transport=self.transport, fetch_schema_from_transport=True)

    def execute_query(self, query_string, variables=None):
        query = gql(query_string)
        result = self.client.execute(query, variable_values=variables)
        return result

      
    def get_user_nfts(self, account):
        query_string = GET_NFTS_OWNER
        variables = {"owner_address": account, "offset": 0}
        result = self.execute_query(query_string, variables=variables)
        return result

    # def get_user_nfts_by_collection(self, account, collection):
      




# def account_balance(input="0x9ee9892d8600ed0bf65173d801ab75204a16ac2c6f190454a3b98f6bcb99d915"):