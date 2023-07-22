# Aptos Arena

Aptos Arena is 2D platform brawler game that leverages composable NFTs with the Aptos Token V2 standard. The game is playable at [https://www.aptosarcade.com/arena](https://www.aptosarcade.com/arena).

To use the package, you must have the [Aptos CLI](https://aptos.dev/tools/install-cli/) installed.

# Compilation

To compile the project, run the following command:

```bash
aptos move run
```

# Testing

Unit tests for all of the user journeys are available in the `tests` directory of this repository. You can run these tests with the following command:

```bash
aptos move test
```

To generate a coverage map for the tests, run this command:

```bash
aptos move test --coverage
```

# Code Coverage

The Aptos Arena contracts are 100% covered by the unit tests. You can see the coverage by running:

```bash
aptos move coverage summary
```

You can see the coverage of each module by running

```bash
aptos move coverage source --module {module_name}
```
