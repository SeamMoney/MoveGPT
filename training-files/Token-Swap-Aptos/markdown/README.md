# Aptoswap

### 📖 Contents

- `pool.move`: The core implementation for Aptoswap.
- `pool_test.move`: The test case and back-testing for `pool.move`.
- `utils.move`: Useful utilities for Aptoswap.  

## 🏃 Getting Started

- Clone the repo:

```shell
git clone git@github.com:black-wyvern-dev/aptoswap.git
```

- Update the submodule of `aptos-core`:

```shell
git submodule update --init --recursive
```

- Run test cases (make sure your `aptos` command line is compatiable with the `aptos-core` in `submodules`):

```
aptos move test
```

- Compile the module:

```shell
# Initialize the ./.aptos
aptos init
# Compile
aptos move compile --named-addresses Aptoswap=default --save-metadata
```

