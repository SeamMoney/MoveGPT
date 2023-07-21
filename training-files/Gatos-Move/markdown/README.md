# Gatos Move Smart Contracts 
Published on Devnet, Alpha version </p>
Three main contracts ; [community](#community), [gamefeed](#gamefeed), [userinfo](#userinfo)

## community 
This module demonstrates a basic community using ACL to control the access.
### Admins 
(1) create their community </p>
(2) add a partipant to its access  control list (ACL) </p>
(3) remove a participant from its ACL
### Users
(1) register for the community board </p>
(2) create a new post </p>
### Events 
The module also emits events for subscribers </p>
(1) post change event, this event contains the board, post and post author
- Devnet Explorer: https://explorer.aptoslabs.com/txn/0x141048390e927e6724259352779578f982b0149caa619ace1855e98c7c23be8e

## gamefeed
This module demonstrates a basic game feed using ACL to control the access.
### Admins 
(1) create their game feed </p>
(2) add a company (of users) to its access control list (ACL) </p>
(3) remove a company from its ACL </p>
### Users
(1) register for the game feed </p>
(2) create a new review </p>
### Events 
The module also emits events for subscribers </p>
(1)review change event, this event contains the board, game and review author
- Devnet Explorer: https://explorer.aptoslabs.com/txn/0x398549025ae42da92fd233d3ed1ab8ba754bc476e239f2907d069559a0f1572d

## userinfo
This module demonstrates a basic user profile management 
### Users
(1) register for the profile board </p>
(2) update a profile </p>
### Events 
The module also emits events for subscribers </p>
(1) profile change event
- Devnet Explorer: https://explorer.aptoslabs.com/txn/0x527fad69d4f5d68e30b5f5eeb1d7ed65cf2c8fbde283de8992f9fdddc3b477e6

## sample
For learning move language and writing smart contracts, we looked through https://aptos.dev/tutorials/build-e2e-dapp/create-a-smart-contract and have tested with it. 
- Devnet Explorer: https://explorer.aptoslabs.com/txn/0xec89b4e16516f931f1e17e5f85889d303e8b2ed3d7f5ea5fca0af367996270da 