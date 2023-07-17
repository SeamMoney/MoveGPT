from flask import Flask, request
from flask_cors import CORS
from flask_cors import cross_origin
from AptosToolClient import account_balance, account_transactions,create_kit,use_moveGPT,use_gh
from ChatAgent import ChatAgent
# from AptosGql import AptosGQLTool

# aQgl = AptosGQLTool()

tool_specs = [
  {
    'name': 'Account Balance',
    'func': account_balance,
    'use': 'find account balance',
    'input':'account to find balance of'
  },
  {
    'name': 'Account Transactions',
    'func': account_transactions,
    'use': 'find account transactions',
    'input':'account to find transactions of'
  },
  {
    'name': 'Move Agent',
    'func': use_moveGPT,
    'use': 'to give information about writing move code or the aptos blockchain when unsure what agent to use use this one',
    'input':'question user has about move or the aptos blockchain'
  },
  # {
  #   'name':"Account NFT Balance",
  #   'func':aQgl.get_user_nfts,
  #   'use':"find account nft balance",
  #   'input':'account to find nft balance of'
    
  # },
  {
    'name': 'Github Chat Agent',
    'func': use_gh,
    'use': 'to chat with github chat agent about generating move code, Feed output into  Move Agent to refine the code',
    'input':'question about how to create move code' 
  }

  
]

tool_kit = create_kit(tool_specs)



chat_agent = ChatAgent(tool_kit)

app = Flask(__name__)
CORS(app)
app.config['CORS_HEADERS'] = 'Content-Type'
app.debug = True
conversations = {}

@app.route('/chat', methods=['POST'])
def chat():
    print("chat")
    payload = request.json
    user_id = payload['user_id']
    convo_id = payload['convo_id']
    user_input = payload['messages']
    # if len(user_input)>1:
    #     agent= conversations[(user_id, convo_id)]
    # else:
    agent = ChatAgent(tool_kit)
    conversations[(user_id, convo_id)]= agent
    response = agent.chat(user_input)
    # save_message(user_id, convo_id, user_input, response)
    return response['output']

def save_message(user_id, convo_id, user_input, response):
    conversation_key = (user_id, convo_id)
    if conversation_key in conversations:
        conversations[conversation_key].append((user_input, response))
    else:
        conversations[conversation_key] = [(user_input, response)]

def end_conversation(user_id, convo_id):
    conversation_key = (user_id, convo_id)
    if conversation_key in conversations:
        del conversations[conversation_key]

@app.route('/conversations', methods=['GET'])
@cross_origin(origin='*')
def get_conversation():
    user_id = request.args.get('user_id')
    convo_id = request.args.get('convo_id')
    conversation_key = (user_id, convo_id)

    if conversation_key in conversations:
        conversation = conversations[conversation_key]
        conversation_str = ""
        for message in conversation:
            user_message, agent_response = message
            conversation_str += f"User: {user_message}\nAgent: {agent_response}\n"
        return conversation_str
    else:
        return "Conversation not found."

if __name__ == '__main__':
    app.run()
