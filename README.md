# Sepolia RPC URL
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com

# Holesky RPC URL  
HOLESKY_RPC_URL=https://ethereum-holesky-rpc.publicnode.com

forge script script/DeployHookWithMining.s.sol:DeployHookWithMining  \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast  \
    -vvvv
forge script script/CreateCompetition.s.sol  \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast  \
    -vvvv

    forge script script/DeployHookWithMining.s.sol:DeployHookWithMining \
    --rpc-url http://localhost:8545 \
    --broadcast \
    -vvvv