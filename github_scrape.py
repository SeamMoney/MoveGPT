import os
import pickle
from llama_index import (
    download_loader,
    GPTSimpleVectorIndex,
    LLMPredictor,
    ServiceContext,
    PromptHelper,
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
            ["aptos-move/framework", "aptos-move/move-examples"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move", ".md"],
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
    {
        "owner": "damirka",
        "repo": "move-book",
        "filter_directories": (
            ["docs/resources", "docs/introduction", "docs/syntax-basics", "docs/tutorials", "docs/advanced-topics"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".md"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "aptos-foundation",
        "repo": "AIPs",
        "filter_directories": (
            ["aips"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".md"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "CetusProtocol",
        "repo": "move-stl",
        "filter_directories": (
            ["aptos/sources"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "CetusProtocol",
        "repo": "cetus-amm",
        "filter_directories": (
            ["aptos/sources"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "AnimeSwap",
        "repo": "v1-core",
        "filter_directories": (
            ["Faucet", "LPCoin", "LPResourceAccount", "Swap", "TestCoin", "u256", "uq64x64"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move", ".md"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "NonceGeek",
        "repo": "MoveDID",
        "filter_directories": (
            ["did-aptos"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move", ".md"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "NonceGeek",
        "repo": "moereum-stdlib",
        "filter_directories": (
            ["sources"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "movedevelopersdao",
        "repo": "Aptos-Move-by-Example",
        "filter_directories": (
            ["why-is-move-secure", "move-vs-solidity", "intermediate-concepts", "hacks", "basic-concepts", "applications", "advanced-concepts"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".md"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
    },
    {
        "owner": "pentagonxyz",
        "repo": "movemate",
        "filter_directories": (
            ["aptos/sources"],
            GithubRepositoryReader.FilterType.INCLUDE,
        ),
        "filter_file_extensions": (
            [".move"],
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
        try:
            repo_docs = loader.load_data(branch="main")
            all_docs.extend(repo_docs)
        except KeyError:
            print(f"Error loading data for {repo['owner']}/{repo['repo']}. Skipping this repository.")


    with open("docs.pkl", "wb") as f:
        pickle.dump(all_docs, f)

llm_predictor = LLMPredictor(
    llm=OpenAI(temperature=0, model_name="text-davinci-003")
)

prompt_helper = PromptHelper(10000, 10000, 20)

service_context = ServiceContext.from_defaults(llm_predictor=llm_predictor, prompt_helper=prompt_helper)

index = GPTSimpleVectorIndex.from_documents(docs, service_context=service_context)

index.save_to_disk("github-vectorStore")
