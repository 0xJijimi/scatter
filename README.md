# Scatter Smart Contract

Scatter is a smart contract that enables efficient distribution of native currency (ETH), ERC20, and ERC1155 tokens to multiple recipients in a single transaction. Built with security in mind, it includes reentrancy protection, pausability, and owner-only emergency withdrawal functions.

## Features

- **Multi-token Support**: Distribute ETH, ERC20, and ERC1155 tokens
- **Batch Transfers**: Send tokens to multiple recipients in one transaction
- **Security Features**:
  - Reentrancy protection
  - Pausable functionality
  - Owner-only emergency withdrawals
  - Comprehensive input validation
- **Gas Optimization**: Special handling for single-recipient ERC1155 transfers
- **Event Logging**: Detailed events for all token distributions

## Official Frontend

The official frontend for Scatter can be accessed [here](https://scatter.jijimi.online/).

## Contract Functions

### Token Distribution

- `scatterNativeCurrency(address[] recipients, uint256[] amounts)`: Distribute ETH to multiple addresses
- `scatterERC20Token(address token, address[] recipients, uint256[] amounts)`: Distribute ERC20 tokens
- `scatterERC1155Token(address token, address[] recipients, uint256[] amounts, uint256[] ids)`: Distribute ERC1155 tokens

### Administrative Functions

- `pause()`: Pause all scatter operations
- `unpause()`: Resume scatter operations
- `withdrawStuckETH()`: Withdraw accidentally sent ETH
- `withdrawStuckERC20(address token)`: Withdraw accidentally sent ERC20 tokens
- `withdrawStuckERC1155(address token, uint256 id)`: Withdraw specific ERC1155 tokens
- `withdrawStuckERC1155Batch(address token, uint256[] ids)`: Batch withdraw ERC1155 tokens

## Directory Structure

```
scatter/
├── src/
│   └── Scatter.sol       # Main contract implementation
├── test/
│   ├── Scatter.t.sol     # Main test suite
│   └── mocks/            # Mock contracts for testing
│       ├── MockERC20.sol
│       ├── MockERC1155.sol
│       ├── RevertingMock.sol
│       └── GasConsumingMock.sol
├── script/
│   └── Scatter.s.sol     # Deployment script
└── lib/                  # Dependencies
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for development tools)
- [Python](https://www.python.org/) (for security analysis)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/0xJijimi/scatter.git
cd scatter
```

2. Install dependencies:
```bash
forge install
```

3. Copy the environment file and configure it:
```bash
cp .env.example .env
```

## Testing

Run the test suite:
```bash
forge test
```

For detailed gas reports:
```bash
forge test --gas-report
```

## Security Analysis

1. Create and activate a Python virtual environment:
```bash
python -m venv .venv
source .venv/bin/activate  # On Windows use: .venv\Scripts\activate
```

2. Install required dependencies:
```bash
pip install -r requirements.txt
```

3. Install solc compiler:
```bash
pip install solc-select
solc-select install 0.8.28  # Install specific version
solc-select use 0.8.28      # Use this version
```

4. Run Slither analysis:
```bash
slither .
```

## Deployment

1. Configure your deployment environment in `.env`

2. Deploy using Foundry:

```bash
# Load environment variables
source .env

# Deploy the contract
forge script script/Scatter.s.sol:DeployScatter --rpc-url $MAINNET_RPC_URL --broadcast -vvvv --slow --ffi

# Verify the contract
forge verify-contract <DEPLOYED_CONTRACT_ADDRESS> <CONTRACT_NAME> --chain-id <CHAIN_ID> --watch

# Deploy AND verify in one command
forge script script/Scatter.s.sol:DeployScatter --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvvv --slow --chain <CHAIN_ID> --ffi
```

## Deployed Contracts

| Network          | Contract Address                           | Explorer Link |
|-----------------|-------------------------------------------|---------------|
| Sonic Mainnet| `0xe907b1f554214129935820fdb8d7e771e1951d67`                           | [View](https://sonicscan.org/address/0xe907b1f554214129935820fdb8d7e771e1951d67) |
| Sonic Blaze Testnet         | `0xf2fc843b45e999fc37e8f8a35f07af0844d388d8`                           | [View](https://testnet.soniclabs.com/address/0xf2fc843b45e999fc37e8f8a35f07af0844d388d8) 

## Events

Monitor these events to track token distributions:

- `NativeCurrencyScattered(address indexed sender, address[] recipients, uint256[] amounts)`
- `ERC20Scattered(address indexed sender, address indexed token, address[] recipients, uint256[] amounts)`
- `ERC1155Scattered(address indexed sender, address indexed token, address[] recipients, uint256[] ids, uint256[] amounts)`

## Security Considerations

- The contract implements reentrancy protection
- All functions perform thorough input validation
- Emergency withdrawal functions are owner-only
- The contract can be paused in case of emergencies
- Token approvals are required before scattering ERC20/ERC1155 tokens

## License

MIT License
