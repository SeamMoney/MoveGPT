# Aptos Arcade

Aptos Arcade is a web-based games platform powered by the [Aptos Blockchain](https://aptos.dev/). It is available at [https://www.aptosarcade.com](https://www.aptosarcade.com).

To use this package, you must have the [Aptos CLI](https://aptos.dev/tools/install-cli/) installed.

# Compilation

To compile the project, run the following command:

```bash
aptos move run
```

# Testing

Unit tests for all the user journeys are available in the `tests` directory of this repository. You can run these tests with the following command:

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