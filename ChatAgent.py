from langchain.agents import Tool, initialize_agent
from langchain.chains.conversation.memory import ConversationBufferWindowMemory

from langchain.chat_models import ChatOpenAI

# Set up the turbo LLM
turbo_llm = ChatOpenAI(
    temperature=0,
    model_name='gpt-3.5-turbo'
) 


class ChatAgent:
    def __init__(self, tools):
        self.tools = tools
        self.memory = ConversationBufferWindowMemory(
            memory_key='chat_history',
            k=3,
            return_messages=True
        )
        self.conversational_agent = initialize_agent(
            agent='chat-conversational-react-description',
            tools=tools,
            llm=turbo_llm,
            verbose=True,
            max_iterations=3,
            early_stopping_method='generate',
            memory=self.memory
        )

  

    def chat(self, message):
        return self.conversational_agent(message)

  
