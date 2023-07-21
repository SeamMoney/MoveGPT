# aptos-sc-starter
#### Main Docs:
>https://aptos.dev/ \
>https://github.com/econia-labs/teach-yourself-move \
#### Install APTOS CLI (MACOS)
>curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3 \
>Add ENV: export PATH="/Users/<username>/.local/bin:$PATH" \
>Docs: https://aptos.dev/cli-tools/aptos-cli-tool/automated-install-aptos-cli/ \
> Install Move Prover (tool for validate your move code): https://aptos.dev/cli-tools/install-move-prover/ \
#### Start to create first contract

##### Create and Fund Aptos Accounts and airdrop APT
>Docs: https://aptos.dev/guides/get-test-funds \
>airdrop to dev wallet: aptos account fund-with-faucet --account afd848a070e55f593f739bdacab6c1c9b526abd39ae8b6f0dd60a53f9db2cebc \
##### Write Smart Contracts with Move \
>Docs: https://aptos.dev/guides/move-guides/aptos-move-guides/ \
>Example: https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples \
>Simulation: https://aptos.dev/concepts/gas-txn-fee/#estimating-the-gas-units-via-simulation \

##### Deploy contract
> Init an account: aptos init --network devnet \
> Init an app: aptos move init --name my_todo_list \
> Build: aptos move compile --bytecode-version 6 \
> Deploy: aptos move publish (https://aptos.dev/tutorials/your-first-dapp/) \
> Unitest: aptos move test \                                        
