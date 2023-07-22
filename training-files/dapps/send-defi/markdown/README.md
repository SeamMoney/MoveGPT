# send-defi

Send DeFi is a general purpose DeFi ecosystem on Aptos. 


## Aptos Move CLI

### Compile Contract
```commandline
aptos move compile
```

### Run Unit Tests

```commandline
aptos move test
```


## Contributing

First off, thanks for taking the time to contribute! Contributions are what makes the open-source community such an amazing place to learn, inspire, and create. Any contributions you make will benefit everybody else and are **greatly appreciated**.

Contributions in the following are welcome:

1. Report a bug.
2. Submit a feature request.
3. Implement feature or fix bug.

### How to add new module to send-defi:

1. Add New Move module to `sources` dir, such as `MyModule.move`.
2. Write Move code and add unit test in the module file.
3. Run script `./script/build.sh` for build and generate documents.

