import os
import logging
import sys
from llama_index import TreeIndex, SimpleDirectoryReader, ComposableGraph, StorageContext

# Set up logging
logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logging.getLogger().addHandler(logging.StreamHandler(stream=sys.stdout))

# Load .move and .md documents
print("Loading documents...")
base_dir = "./dapps"
move_documents = []
md_documents = []

for dapp_dir in os.listdir(base_dir):
    move_dir = os.path.join(base_dir, dapp_dir, "move")
    md_dir = os.path.join(base_dir, dapp_dir, "markdown")
    if os.path.exists(move_dir):
        print(f"Loading .move documents from {move_dir}...")
        move_docs = SimpleDirectoryReader(move_dir).load_data()
        print(f"Loaded {len(move_docs)} .move documents.")
        move_documents.extend(move_docs)
    if os.path.exists(md_dir):
        print(f"Loading .md documents from {md_dir}...")
        md_docs = SimpleDirectoryReader(md_dir).load_data()
        print(f"Loaded {len(md_docs)} .md documents.")
        md_documents.extend(md_docs)

# Create TreeIndex for each document
print("Creating TreeIndex for .move and .md files...")
storage_context = StorageContext.from_defaults(persist_dir=".")

move_indices = [TreeIndex.from_documents([doc], storage_context=storage_context) for doc in move_documents]
md_indices = [TreeIndex.from_documents([doc], storage_context=storage_context) for doc in md_documents]

# Define summary text for each subindex
move_index_summaries = ["This is a summary for move document {}".format(i) for i in range(len(move_documents))]
md_index_summaries = ["This is a summary for md document {}".format(i) for i in range(len(md_documents))]

# Create a ComposableGraph
print("Creating ComposableGraph...")
graph = ComposableGraph.from_indices(
    TreeIndex,
    move_indices + md_indices,
    index_summaries=move_index_summaries + md_index_summaries,
    storage_context=storage_context,
)

print("Done!")
print(f"Total .move documents loaded: {len(move_documents)}")
print(f"Total .md documents loaded: {len(md_documents)}")

custom_query_engines = {
    index.index_id: index.as_query_engine(
        similarity_top_k=3,
        response_mode="generation",
    )
}

query_engine = graph.as_query_enginer(custom_query_engines=custom_query_engines)

# Query the graph
query = "write a move module called fibonacci that computes the nth fibonacci number where n is the argument to the fib function inside the fibonacci module. then write a separate move script that imports the fibonacci module and tests the fib function with the number 5?"
results = query_engine.query(query)

# Print the results
print(type(result))
print(result)
