import os
import logging
import sys
from llama_index import VectorStoreIndex, SimpleDirectoryReader, ComposableGraph, SimpleKeywordTableIndex
from llama_index import ServiceContext, set_global_service_context
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Set up logging
logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logging.getLogger().addHandler(logging.StreamHandler(stream=sys.stdout))

# Load .move and .md documents
print("Loading documents...")
base_dir = "/workspaces/MoveGPT/training-files/dapps"
move_documents = []
md_documents = []

for dapp_dir in os.listdir(base_dir):
    move_dir = os.path.join(base_dir, dapp_dir, "move")
    md_dir = os.path.join(base_dir, dapp_dir, "markdown")
    
    if os.path.exists(move_dir):
        move_documents.extend(SimpleDirectoryReader(move_dir).load_data())
    if os.path.exists(md_dir):
        md_documents.extend(SimpleDirectoryReader(md_dir).load_data())

# Create VectorStoreIndex for .move and .md files
print("Creating VectorStoreIndex for .move and .md files...")
move_index_file = "/workspaces/MoveGPT/training-files/move_index.pkl"
md_index_file = "/workspaces/MoveGPT/training-files/md_index.pkl"

if os.path.exists(move_index_file):
    print("Loading existing .move index from disk...")
    move_index = VectorStoreIndex.load(move_index_file)
else:
    print("Creating new .move index...")
    move_index = VectorStoreIndex.from_documents(move_documents)
    move_index.save(move_index_file)

if os.path.exists(md_index_file):
    print("Loading existing .md index from disk...")
    md_index = VectorStoreIndex.load(md_index_file)
else:
    print("Creating new .md index...")
    md_index = VectorStoreIndex.from_documents(md_documents)
    md_index.save(md_index_file)

# Set summaries for the indices
move_index_summary = "This index contains .move files for smart contracts on the Aptos blockchain."
md_index_summary = "This index contains .md files that explain the technical documentation for the Move language."

# Create a ComposableGraph
print("Creating ComposableGraph...")
graph = ComposableGraph.from_indices(
    SimpleKeywordTableIndex,
    [move_index, md_index],
    index_summaries=[move_index_summary, md_index_summary],
    max_keywords_per_chunk=50,
)

print("Done!")