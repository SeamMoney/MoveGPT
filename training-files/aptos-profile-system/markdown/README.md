# Aptos Profile System
Universal Profile System on Aptos

#### Intro
Based on the properties of Move language on Aptos, resources can be stored under account. So it's easy to build a Universal Profile System that connects profile data with accounts, and it's also easy to access accounts' profiles.

#### Details
We built a profile module and defined resources called 'Profile', including unique username, description, avatar URI, friends etc in the struct. Then defind a public function called 'register', which takes personal info as parameters to create a Profile and move it under a user's account. This profile data can be used in every web3 or event web2 apps without building a new profile everytime your sign in a new app.

#### Cases
There's only on app using this Profile System
 - [Aptos InChat](https://github.com/JustaLiang/aptos-inchat-module)