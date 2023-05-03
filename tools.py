from AptosToolClient import account_balance, account_transactions, create_kit, use_moveGPT, use_gh
from AptosGql import AptosGQLTool

aQgl = AptosGQLTool()

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
    'use': 'to give information about move or the aptos blockchain',
    'input':'question user has about move or the aptos blockchain'
  },
  {
    'name': 'Github Chat Agent',
    'func': use_gh,
    'use': 'to chat with github chat agent about generating move code, Feed output into         Move Agent to refine the code',
    'input':'question about how to create move code' 
  }
]

tool_kit = create_kit(tool_specs)
