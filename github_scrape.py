import pickle
import os

from llama_index import download_loader, GPTSimpleVectorIndex, LLMPredictor, ServiceContext

download_loader("GithubRepositoryReader")
from llama_index.readers.llamahub_modules.github_repo import GithubClient, GithubRepositoryReader
from langchain import OpenAI

docs = None
if os.path.exists("docs.pkl"):
  with open("docs.pkl", "rb") as f:
    docs = pickle.load(f)

if docs is None:
  github_client = GithubClient(os.getenv("GITHUB_TOKEN"))
  loader = GithubRepositoryReader(
    github_client,
    owner="aptos-labs",
    repo="aptos-core",
    filter_directories=(["aptos-move/framework"],
                        GithubRepositoryReader.FilterType.INCLUDE),
    filter_file_extensions=([".move"],
                            GithubRepositoryReader.FilterType.INCLUDE),
    verbose=True,
    concurrent_requests=10,
  )

  docs = loader.load_data(branch="main")

  with open("docs.pkl", "wb") as f:
    pickle.dump(docs, f)

llm_predictor = LLMPredictor(
  llm=OpenAI(temperature=0, model_name="text-davinci-003", max_tokens=5000))

service_context = ServiceContext.from_defaults(llm_predictor=llm_predictor)

index = GPTSimpleVectorIndex.from_documents(docs,
                                            service_context=service_context)

index.save_to_disk("github-vectorStore")
