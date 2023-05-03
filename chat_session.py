from ChatAgent import ChatAgent
from tools import tool_kit

class ChatSession:
    def __init__(self):
        self.chat_agent = ChatAgent(tool_kit)

    def chat(self, user_input):
        return self.chat_agent.chat(user_input)
