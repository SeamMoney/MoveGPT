import pickle
import os

from llama_index import (
    download_loader,
    GPTSimpleVectorIndex,
    LLMPredictor,
    ServiceContext,
)

download_loader("GithubRepositoryReader")
from llama_index.readers.llamahub_modules.github_repo import (
    GithubClient,
    GithubRepositoryReader,
)
from langchain import OpenAI

repos = {
    "econia": "https://github.com/econia-labs/econia/tree/main/src/move",
}

docs = None
if os.path.exists("docs.pkl"):
    with open("docs.pkl", "rb") as f:
        docs = pickle.load(f)

if docs is None:
    github_client = GithubClient(os.getenv("GITHUB_TOKEN"))

    aptos_core_loader = GithubRepositoryReader(
        github_client,
        owner="aptos-labs",
        repo="aptos-core",
        filter_directories=(
            ["aptos-move/framework"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        filter_file_extensions=([".move"],
                                GithubRepositoryReader.FilterType.INCLUDE),
        verbose=True,
        concurrent_requests=10,
    )

    econia_loader = GithubRepositoryReader(
        github_client,
        owner="econia-labs",
        repo="econia",
        filter_directories=(
            ["src/move"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        filter_file_extensions=([".move", ".md"],
                                GithubRepositoryReader.FilterType.INCLUDE),
        verbose=True,
        concurrent_requests=10,
    )

    ferum_loader_1 = GithubRepositoryReader(
        github_client,
        owner="ferumlabs",
        repo="ferum-std",
        filter_directories=(
            ["sources", "docs"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        filter_file_extensions=([".move", ".md"],
                                GithubRepositoryReader.FilterType.INCLUDE),
        verbose=True,
        concurrent_requests=10,
    )

    ferum_loader_2 = GithubRepositoryReader(
        github_client,
        owner="ferumlabs",
        repo="ferum",
        filter_directories=(
            ["contract"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        filter_file_extensions=([".move", ".md"],
                                GithubRepositoryReader.FilterType.INCLUDE),
        verbose=True,
        concurrent_requests=10,
    )

    move_book_loader = GithubRepositoryReader(
        github_client,
        owner="move-language",
        repo="move",
        filter_directories=(
            [
                "language/move-stdlib/docs", "language/move-stdlib/sources",
                "language/move-stdlib/nursery", "language/documentation"
            ],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        filter_file_extensions=([".move", ".md"],
                                GithubRepositoryReader.FilterType.INCLUDE),
        verbose=True,
        concurrent_requests=10,
    )

    aptos_docs = aptos_core_loader.load_data(branch="main")
    econia_docs = econia_loader.load_data(branch="main")
    ferum_docs_1 = ferum_loader_1.load_data(branch="main")
    ferum_docs_2 = ferum_loader_2.load_data(branch="main")

    with open("docs.pkl", "wb") as f:
        pickle.dump(aptos_docs, f)
        pickle.dump(econia_docs, f)

llm_predictor = LLMPredictor(
    llm=OpenAI(temperature=0, model_name="text-davinci-003", max_tokens=5000))

service_context = ServiceContext.from_defaults(llm_predictor=llm_predictor)

index = GPTSimpleVectorIndex.from_documents(docs,
                                            service_context=service_context)

index.save_to_disk("github-vectorStore")
