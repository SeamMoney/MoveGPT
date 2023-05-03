from chat_session import ChatSession

print("Welcome to the CLI. Type 'quit' to exit.")

chat_session = ChatSession()

while True:
  user_input = input("User: ")
  if user_input.lower() == 'quit':
    break
  response = chat_session.chat(user_input)
  print(f"Agent: {response}")
  
