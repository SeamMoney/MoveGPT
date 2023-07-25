import os
import logging
import sys
from llama_index import VectorStoreIndex, SimpleDirectoryReader, ComposableGraph, StorageContext, ServiceContext, set_global_service_context
from llama_index.llms import Replicate
from llama_index.llms.llama_utils import messages_to_prompt, completion_to_prompt
import openai

# Set up logging
logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logging.getLogger().addHandler(logging.StreamHandler(stream=sys.stdout))

# Set API keys
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
REPLICATE_API_TOKEN = os.getenv("REPLICATE_API_TOKEN")

# Define Llama 2 model
LLAMA_13B_V2_CHAT = "a16z-infra/llama13b-v2-chat:df7690f1994d94e96ad9d568eac121aecf50684a0b0963b25a41cc40061269e5"

# Define custom completion to prompt function
def custom_completion_to_prompt(completion: str) -> str:
    return completion_to_prompt(
        completion,
        system_prompt=(
            "You are MoveGPT, the all knowing master of the move programming language. Your goal is to learn as much as you can about the Aptos blockchain, the move programming language, and the implementation of the aptos_framework and understand all of its deployed modules along with their functions. You will output code to the user with proper use statements. These are needed whenever a function is defined outside of the module of the code output. In move to call a function, you will first need to import the module, then call the function. To import a module, you will use the following syntax: use address::module_name::function To call a function, you will use the following syntax: module_name::function(...parameters) \n\nA 'module' is defined as:\n\nmodule moduleName [\n    public fun moduleFunction(...params): returnType [\n        // code\n    ]\n]\n\nA 'struct' is defined as:\n\nstruct StructName  [\n  name: type\n]\n\nA function to run only in test mode is defined as:\n\n#[test]\npublic entry fun test_max() []\n    let result = max(3u128, 6u128);\n    assert!(result == 6, 0);\n\n    let result = max(15u128, 12u128);\n    assert!(result == 15, 1);\n]\n\nFor basic variable types you must import them from the aptos_framework package. Such as:\n\nuse std::vector;\nuse aptos_framework::account;\nuse aptos_framework::resource_account;\nuse aptos_framework::coin;\nuse std::string;\nuse std::error;\nuse std::signer;\nuse std::vector;\n\nAn 'assert' statement can be used to check for a condition.\n\nassert(condition, message)\n\nTypes like string, vector, coin, account, resource_account, signer are all lowercase. Here are use cases for option and vector:\n\nuse std::option;\nuse std::vector;\n\nusing the module:\nvector::some_function vector::new_vector<X>(int size)\n\nUse the following pieces of MemoryContext to answer the human. ConversationHistory is a list of Conversation objects, which corresponds to the conversation you are having with the human.\n---\nConversationHistory: {history}\n---\nMemoryContext: {context}\n---\nHuman: {prompt}\nmoveGPT:"
        ),
    )

# Define LLM
llm = Replicate(
    model=LLAMA_13B_V2_CHAT,
    temperature=0.01,
    context_window=4096,
    completion_to_prompt=custom_completion_to_prompt,
    messages_to_prompt=messages_to_prompt,
)

# Set a global service context
ctx = ServiceContext.from_defaults(llm=llm)
set_global_service_context(ctx)

# Load .move and .md documents
print("Loading documents...")
base_dir = "./dapps"
documents = []

for dapp_dir in os.listdir(base_dir):
    move_dir = os.path.join(base_dir, dapp_dir, "move")
    md_dir = os.path.join(base_dir, dapp_dir, "markdown")
    if os.path.exists(move_dir):
        print(f"Loading .move documents from {move_dir}...")
        move_docs = SimpleDirectoryReader(move_dir).load_data()[:2]  # Limit to 10 documents
        print(f"Loaded {len(move_docs)} .move documents.")
        documents.extend(move_docs)
    if os.path.exists(md_dir):
        print(f"Loading .md documents from {md_dir}...")
        md_docs = SimpleDirectoryReader(md_dir).load_data()[:2]  # Limit to 10 documents
        print(f"Loaded {len(md_docs)} .md documents.")
        documents.extend(md_docs)

# Create VectorStoreIndex
print("Creating VectorStoreIndex...")
index = VectorStoreIndex.from_documents(documents)

# Create a ComposableGraph
print("Creating ComposableGraph...")
graph = ComposableGraph.from_indices(
    VectorStoreIndex,
    [index],
    index_summaries = [
    "This index contains Move code for smart contracts on the Aptos blockchain and Markdown files documenting the Aptos protocol and standard library. It also includes applications deployed to Aptos such as Econia, Satay Finance, AnimeSwap, LiquidSwap, Pontem Network, Cetus Finance, and others."
],
    storage_context=StorageContext.from_defaults(persist_dir="."),
)

# Configure query engines
custom_query_engines = {
    index.index_id: index.as_query_engine(
        similarity_top_k=3,
        response_mode="generation",
    )
}

query_engine = graph.as_query_engine(custom_query_engines=custom_query_engines)

# Query the index
query = "Move module for a simple coin"
result = query_engine.query(query)
print(type(result))
print(result)

