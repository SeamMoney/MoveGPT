from langchain.llms import OpenAI
from langchain.agents import load_tools,initialize_agent
from langchain.agents import AgentType
from langchain.tools import AIPluginTool

from langchain.agents.agent_toolkits.openapi.spec import reduce_openapi_spec

import yaml, os
with open("./training/aptos_openapi.yaml") as f:
    raw_klarna_api_spec = yaml.load(f, Loader=yaml.Loader)
    klarna_api_spec = reduce_openapi_spec(raw_klarna_api_spec)
    print(klarna_api_spec)
# 
# if __name__ == '__main__':
#     # Setup environment variables
#     import os
#     # DEV_ENV = os.environ['DEV'] == 'true'
#     # URL = "http://localhost:3333" if DEV_ENV else "https://solana-gpt-plugin.onrender.com"

#     # llm = LLMPredictor(
#     llm=OpenAI(temperature=0, model_name="text-davinci-003", max_tokens=5000)

#     # AI Agent does best when it only has one available tool
#     # to engage with URLs
#     tools = load_tools(["requests_post"])

#     # AIPluginTool only fetches and returns the openapi.yaml linked to in /.well-known/ai-plugin.json
#     # This may need some more work to avoid blowing up LLM context window
#     tool = AIPluginTool.from_openapi_spec(path="./training/aptos_openapi.yaml")
#     tools += [tool]

#     # Setup an agent to answer the question without further human feedback
#     agent_chain = initialize_agent(
#         tools, llm, agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION, verbose=True)

#     # Ask the question, and the agent loop
#     agent_chain.run(
#         "How many aptos 0xba78c665ccef66de6e6ca1fd085a9a2e3e08ef65998df3f419a555e8039f3987 have?")