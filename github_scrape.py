import os
import pickle
from llama_index import (
    download_loader,
    GPTSimpleVectorIndex,
    LLMPredictor,
    ServiceContext,
)
from llama_index.readers.llamahub_modules.github_repo import (
    GithubClient,
    GithubRepositoryReader,
)
from langchain import OpenAI

download_loader("GithubRepositoryReader")

repos = [
    {
        "owner": "aptos-labs",
        "repo": "aptos-core",
        "filter_directories": (
            ["aptos-move/framework"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "econia-labs",
        "repo": "econia",
        "filter_directories": (
            ["src/move"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move", ".md"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "x24870",
        "repo": "move_fastly",
        "filter_directories": (
            ["bridge", "counter", "message", "nft", "upgrade_counter"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "villesundell",
        "repo": "move-patterns",
        "filter_directories": (
            ["src"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".md"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    # Add other repository configurations here
]

docs = None
if os.path.exists("docs.pkl"):
    with open("docs.pkl", "rb") as f:
        docs = pickle.load(f)

if docs is None:
    github_client = GithubClient(os.getenv("GITHUB_TOKEN"))
    all_docs = []

    for repo in repos:
        loader = GithubRepositoryReader(
            github_client,
            owner=repo["owner"],
            repo=repo["repo"],
            filter_directories=repo["filter_directories"],
            filter_file_extensions=repo["filter_file_extensions"],
            verbose=True,
            concurrent_requests=10,
        )
        repo_docs = loader.load_data(branch="main")
        all_docs.extend(repo_docs)

    with open("docs.pkl", "wb") as f:
        pickle.dump(all_docs, f)

llm_predictor = LLMPredictor(
    llm=OpenAI(temperature=0, model_name="text-davinci-003", max_tokens=5000)
)

service_context = ServiceContext.from_defaults(llm_predictor=llm_predictor)

index = GPTSimpleVectorIndex.from_documents(docs, service_context=service_context)

index.save_to_disk("github-vectorStore")
