from langchain.agents import Tool
from langchain.tools import BaseTool
from aptos_sdk.client import Account
import aptos_sdk
import requests
from aptos_sdk.client import FaucetClient, RestClient
from langchain.agents import initialize_agent
from typing_extensions import dataclass_transform
from ctypes import resize
import requests

import pickle
import os
import hnswlib
from llama_index import GPTVectorStoreIndex
from llama_index import load_index_from_storage

NODE_URL = "https://fullnode.mainnet.aptoslabs.com/v1"
MOVE_URL = "http://localhost:3000/"
client = RestClient(NODE_URL)

APT_SCALE = 100000000
# defining a single tool
tools = []
# store = hnswlib.load_index("github-vectorStore")
# vector_store = GPTVectorStoreIndex.from_vector_store(store)
# vector_store = load_index_from_storage("github-vectorStore")



def format_tool_prompt(tool_name, tool_function, tool_input):
    return f"{tool_name}: useful when {tool_function} input:{tool_input}"


def create_tool(tool_name, tool_function, tool_use, tool_input):
    tool_desc = format_tool_prompt(tool_name, tool_function, tool_input)
    tool = Tool(
        name=tool_name,
        func=tool_function,
        description=tool_desc,
    )
    return tool


def create_kit(tool_specs):
    tools = []
    for tool_spec in tool_specs:
        tools.append(
            create_tool(tool_name=tool_spec['name'],
                        tool_function=tool_spec['func'],
                        tool_use=tool_spec['use'],
                        tool_input=tool_spec['input']))
    return tools


def use_moveGPT(input="what is move"):
    req = requests.post(MOVE_URL + "generate-response",
                        json={"question": input})
    return req.json()['answer']


def use_gh(input="what is move"):
    # q = vector_store.query(input)
    return input


# THESE ARE THE FUNCTIONS TO BE USED BY THE TOOLS
def account_balance(
    input="0x9ee9892d8600ed0bf65173d801ab75204a16ac2c6f190454a3b98f6bcb99d915"
):
    res = float(client.account_balance(input)) / APT_SCALE
    return res


# def resolve_dapp_address():
#   account_transactions("0x9ee9892d8600ed0bf65173d801ab75204a16ac2c6f190454a3b98f6bcb99d915")

# downside only does recent gql for this?

# def module_question()


def split_function(func_str):
    parts = func_str.split("::")
    return {'address': parts[0], 'module': parts[1], 'function': parts[2]}


def account_transactions(input="0x1"):

    req = requests.get(NODE_URL + "/accounts/" + input + '/transactions')
    txs = []
    if (req):
        data = req.json()
        for d in data:
            payload = d['payload']
            # print(payload)
            f = split_function(payload['function'])
            tx = {}
            tx['address'] = f['address']
            tx['module'] = f['module']
            tx['function'] = f['function']
            if payload['type_arguments']:
                tx['type_arguments'] = payload['type_arguments']
            if payload['arguments']:
                tx['arguments'] = payload['arguments']
            txs.append(tx)
            # })
        return txs[:2]


def account_modules(input="0x1"):
    req = requests.get(NODE_URL + "/accounts/" + input + '/modules')

    if req:
        data = req.json()
        function_list = []

        for module in data:
            functions = module.get('abi', {}).get('exposed_functions', [])
            function_info = []

            for func in functions:
                func_name = func['name']
                param_types = [param for param in func.get('params', [])]

                func_string = format_func(module['name'], func_name,
                                          param_types)
                function_info.append(func_string)
            function_list.append(function_info)

        return function_list
    else:
        return []


# need to fix to prop format types
def format_func(mod_name, func_name, param_types):
    return f"{mod_name}::{func_name}::({', '.join(param_types)})"


# def account_nft_balance(input="0x1"):
