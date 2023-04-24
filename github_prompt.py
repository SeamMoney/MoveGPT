import pickle
import os

from llama_index import GPTSimpleVectorIndex

vector_store = GPTSimpleVectorIndex.load_from_disk("github-vectorStore")

response = vector_store.query("write move code for a tree data structure with insert node and remove node functions")

print(response)