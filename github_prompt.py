import pickle
import os

from llama_index import GPTSimpleVectorIndex

vector_store = GPTSimpleVectorIndex.load_from_disk("github-vectorStore")

response = vector_store.query("write a move module that creates an NFT collection of 100")

print(response)