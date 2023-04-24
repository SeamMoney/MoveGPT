import pickle
import os

from llama_index import download_loader, GPTSimpleVectorIndex
download_loader("GithubRepositoryReader")

from llama_index.readers.llamahub_modules.github_repo import GithubClient, GithubRepositoryReader

docs = None
if os.path.exists("docs.pkl"):
    with open("docs.pkl", "rb") as f:
        docs = pickle.load(f)

if docs is None:
    github_client = GithubClient(os.getenv("GITHUB_TOKEN"))
    loader = GithubRepositoryReader(
        github_client,
        owner =                  "SeamMoney",
        repo =                   "MoveGPT",
        filter_directories =     (["langchain-move", "langchain-move/move-files"], GithubRepositoryReader.FilterType.INCLUDE),
        filter_file_extensions = ([".move"], GithubRepositoryReader.FilterType.INCLUDE),
        verbose =                True,
        concurrent_requests =    10,
    )

    docs = loader.load_data(branch="main")

    with open("docs.pkl", "wb") as f:
        pickle.dump(docs, f)

index = GPTSimpleVectorIndex.from_documents(docs)

index.save_to_disk("github-vectorStore")
# print(index.query("Write a Move smart contract module"))