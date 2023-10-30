# DeploymIntent™

`DeploymIntent` is a Seaport zone that allows users to incentivize the deployment of arbitrary smart contracts through the use of Seaport orders and stateful zone hooks.

A Seaport order that specifies the `DeploymIntent` zone can only be fulfilled if the zone passes the `validateOrder` hook.

The `validateOrder` hook uses the initialization code, salt, and (optionally) initial native token value provided via `extraData` to deploy an arbitrary smart contract. The resulting smart contract address is hashed with the `initialValue` parameter, and the result is compared to the `zoneHash` on the order. If the hashes match, the order is fulfilled; otherwise, the order is rejected.

Users can use the `DeploymIntent` zone to offer any combination of ERC20, ERC721, and ERC1155 tokens to incentivize the deployment of arbitrary smart contracts. Note that native token incentives are not currently supported, as there is no approval mechanism for native token transfers; wrapped native tokens (such as WETH) can be used instead.
