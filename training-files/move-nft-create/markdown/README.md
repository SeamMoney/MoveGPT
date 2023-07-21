# Move NFT Create

This is a [Next.js](https://nextjs.org/) project bootstrapped with [`create-next-app`](https://github.com/vercel/next.js/tree/canary/packages/create-next-app).

## Getting Started

- Downloads all the packages and run the tests
```
yarn install or npm install 
```

Run the development server:

```bash
npm run dev
# or
yarn dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `pages/index.tsx`. The page auto-updates as you edit the file.

[API routes](https://nextjs.org/docs/api-routes/introduction) can be accessed on [http://localhost:3000/api/hello](http://localhost:3000/api/hello). This endpoint can be edited in `pages/api/hello.ts`.

The `pages/api` directory is mapped to `/api/*`. Files in this directory are treated as [API routes](https://nextjs.org/docs/api-routes/introduction) instead of React pages.

## Run Aptos

Make sure that you have `aptos` cli installed. If not install it from here: https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/

- Set the current network in [`utils/constants.ts#L18`](./utils/constants.ts#L18)
```
export const CURRENT_NETWORK = Network.LOCAL;
```
- Run the local node in another terminal ( since the local node runs at port `:8080` and `:8081` , make sure it is free and the `force-restart` deletes the previous logs and starts a fresh session )
```
aptos node run-local-testnet --with-faucet --force-restart --assume-yes
```
- Compile the module
```
aptos move compile
```
- Run the test cases
```
aptos move test
```
- Publish the module with a new account
```
aptos init --profile newAccount
aptos move publish --profile newAccount
```
The aptos init creates a new keypair using which the module can be published.
Note: Publishing the module with the current address wont be possible since the auth key is not present. You would have to create a new keypair and then
replace it in move.toml and MODULE_OWNER_ADDRESS in [`utils/constants.ts`](./utils/constants.ts) to continue.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js/) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/deployment) for more details.
