pragma solidity 0.5.9;

import "../../contracts_common/src/Libraries/SafeMathWithRequire.sol";
import "../Land.sol";
import "../../contracts_common/src/Interfaces/ERC20.sol";
import "../../contracts_common/src/BaseWithStorage/MetaTransactionReceiver.sol";
import "../../contracts_common/src/Interfaces/Medianizer.sol";

/**
 * @title Land Sale contract
 * @notice This contract mananges the sale of our lands
 */
contract LandSale is MetaTransactionReceiver {
    using SafeMathWithRequire for uint256;

    uint256 internal constant GRID_SIZE = 408; // 408 is the size of the Land
    uint256 internal constant tokenPriceInUsd = 14400000000000000;

    Land internal _land;
    ERC20 internal _erc20;
    Medianizer private _medianizer;
    ERC20 private _dai;
    address payable internal _wallet;
    uint256 internal _expiryTime;
    bytes32 internal _merkleRoot;

    bool _erc20Enabled = true;
    bool _etherEnabled = false;
    bool _daiEnabled = false;

    event LandQuadPurchased(
        address indexed buyer,
        address indexed to,
        uint256 indexed topCornerId,
        uint16 size,
        uint256 price,
        address token,
        uint256 amountPaid
    );

    constructor(
        address landAddress,
        address erc20ContractAddress,
        address initialMetaTx,
        address admin,
        address payable initialWalletAddress,
        bytes32 merkleRoot,
        uint256 expiryTime,
        address medianizerContractAddress,
        address daiTokenContractAddress
    ) public {
        _land = Land(landAddress);
        _erc20 = ERC20(erc20ContractAddress);
        _setMetaTransactionProcessor(initialMetaTx, true);
        _admin = admin;
        _wallet = initialWalletAddress;
        _merkleRoot = merkleRoot;
        _expiryTime = expiryTime;
        _medianizer = Medianizer(medianizerContractAddress);
        _dai = ERC20(daiTokenContractAddress);
    }

    /// @notice set the wallet receiving the proceeds
    /// @param newWallet address of the new receiving wallet
    function setReceivingWallet(address payable newWallet) external{
        require(newWallet != address(0), "receiving wallet cannot be zero address");
        require(msg.sender == _admin, "only admin can change the receiving wallet");
        _wallet = newWallet;
    }

    /// @notice enable/disable DAI payment for Lands
    /// @param enabled whether to enable or disable
    function setDAIEnabled(bool enabled) external {
        require(msg.sender == _admin, "only admin can enable/disable DAI");
        _daiEnabled = enabled;
    }

    /// @notice return whether DAI payments are enabled
    /// @return whether DAI payments are enabled
    function isDAIEnabled() external returns (bool) {
        return _daiEnabled;
    }

    /// @notice enable/disable ETH payment for Lands
    /// @param enabled whether to enable or disable
    function setETHEnabled(bool enabled) external {
        require(msg.sender == _admin, "only admin can enable/disable ETH");
        _etherEnabled = enabled;
    }

    /// @notice return whether ETH payments are enabled
    /// @return whether ETH payments are enabled
    function isETHEnabled() external returns (bool) {
        return _etherEnabled;
    }

    /// @notice enable/disable the specific ERC20 payment for Lands
    /// @param enabled whether to enable or disable
    function setERC20Enabled(bool enabled) external {
        require(msg.sender == _admin, "only admin can enable/disable ERC20");
        _erc20Enabled = enabled;
    }

    /// @notice return whether the specific ERC20 payments are enabled
    /// @return whether the specific ERC20 payments are enabled
    function isERC20Enabled() external returns (bool) {
        return _erc20Enabled;
    }

    function _checkValidity(
        address buyer,
        address reserved,
        uint16 x,
        uint16 y,
        uint16 size,
        uint256 price,
        bytes32 salt,
        bytes32[] memory proof
    ) internal {
        /* solium-disable-next-line security/no-block-members */
        require(block.timestamp < _expiryTime, "sale is over");
        require(buyer == msg.sender || _metaTransactionContracts[msg.sender], "not authorized");
        require(reserved == address(0) || reserved == buyer, "cannot buy reserved Land");
        bytes32 leaf = _generateLandHash(x, y, size, price, reserved, salt);

        require(
            _verify(proof, leaf),
            "Invalid land provided"
        );
    }

    function _mint(address buyer, address to, uint16 x, uint16 y, uint16 size, uint256 price, address token, uint256 tokenAmount) internal {
         _land.mintQuad(to, size, x, y);
        emit LandQuadPurchased(buyer, to, x + (y * GRID_SIZE), size, price, token, tokenAmount);
    }

    /**
     * @notice buy Land with ERC20 using the merkle proof associated with it
     * @param buyer address that perform the payment
     * @param to address that will own the purchased Land
     * @param reserved the reserved address (if any)
     * @param x x coordinate of the Land
     * @param y y coordinate of the Land
     * @param size size of the pack of Land to purchase
     * @param price dollars price to purchase that Land
     * @param proof merkleProof for that particular Land
     * @return The address of the operator
     */
    function buyLandWithERC20(
        address buyer,
        address to,
        address reserved,
        uint16 x,
        uint16 y,
        uint16 size,
        uint256 price,
        bytes32 salt,
        bytes32[] calldata proof
    ) external {
        require(_erc20Enabled, "erc20 payments not enabled");
        _checkValidity(buyer, reserved, x, y, size, price, salt, proof);
        uint256 tokenAmount = price.mul(1000000000000000000).div(tokenPriceInUsd);
        require(
            _erc20.transferFrom(
                buyer,
                _wallet,
                tokenAmount
            ),
            "erc20 token transfer failed"
        );
        _mint(buyer, to, x, y, size, price, address(_erc20), tokenAmount);
    }

    /**
     * @notice buy Land with ETH using the merkle proof associated with it
     * @param buyer address that perform the payment
     * @param to address that will own the purchased Land
     * @param reserved the reserved address (if any)
     * @param x x coordinate of the Land
     * @param y y coordinate of the Land
     * @param size size of the pack of Land to purchase
     * @param price dollars price to purchase that Land
     * @param proof merkleProof for that particular Land
     * @return The address of the operator
     */
    function buyLandWithETH(
        address buyer,
        address to,
        address reserved,
        uint16 x,
        uint16 y,
        uint16 size,
        uint256 price,
        bytes32 salt,
        bytes32[] calldata proof
    ) external payable {
        require(_etherEnabled, "ether payments not enabled");
        _checkValidity(buyer, reserved, x, y, size, price, salt, proof);

        uint256 ETHRequired = getEtherAmountWithUSD(price);
        require(msg.value >= ETHRequired, "not enough ether sent");
        uint256 leftOver = msg.value - ETHRequired;
        if(leftOver > 0) {
            msg.sender.transfer(leftOver); // refund extra
        }
        address(_wallet).transfer(ETHRequired);

        _mint(buyer, to, x, y, size, price, address(0), ETHRequired);
    }

    /**
     * @notice buy Land with DAI using the merkle proof associated with it
     * @param buyer address that perform the payment
     * @param to address that will own the purchased Land
     * @param reserved the reserved address (if any)
     * @param x x coordinate of the Land
     * @param y y coordinate of the Land
     * @param size size of the pack of Land to purchase
     * @param price dollars price to purchase that Land
     * @param proof merkleProof for that particular Land
     * @return The address of the operator
     */
    function buyLandWithDAI(
        address buyer,
        address to,
        address reserved,
        uint16 x,
        uint16 y,
        uint16 size,
        uint256 price,
        bytes32 salt,
        bytes32[] calldata proof
    ) external {
        require(_daiEnabled, "dai payments not enabled");
        _checkValidity(buyer, reserved, x, y, size, price, salt, proof);

        require(_dai.transferFrom(msg.sender, _wallet, price), "failed to transfer dai");

        _mint(buyer, to, x, y, size, price, address(_dai), price);
    }

    /**
     * @notice Gets the expiry time for the current sale
     * @return The expiry time, as a unix epoch
     */
    function getExpiryTime() external view returns(uint256) {
        return _expiryTime;
    }

    /**
     * @notice Gets the Merkle root associated with the current sale
     * @return The Merkle root, as a bytes32 hash
     */
    function merkleRoot() external view returns(bytes32) {
        return _merkleRoot;
    }

    function _generateLandHash(
        uint16 x,
        uint16 y,
        uint16 size,
        uint256 price,
        address reserved,
        bytes32 salt
    ) internal pure returns (
        bytes32
    ) {
        return keccak256(
            abi.encodePacked(
                x,
                y,
                size,
                price,
                reserved,
                salt
            )
        );
    }

    function _verify(bytes32[] memory proof, bytes32 leaf) internal view returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == _merkleRoot;
    }

    /**
     * @notice Returns the amount of ETH for a specific amount of USD
     * @param usdAmount An amount of USD
     * @return The amount of ETH
     */
    function getEtherAmountWithUSD(uint256 usdAmount) public view returns (uint256) {
        uint256 ethUsdPair = getEthUsdPair();
        return usdAmount.mul(1000000000000000000).div(ethUsdPair);
    }

    /**
     * @notice Gets the ETHUSD pair from the Medianizer contract
     * @return The pair as an uint256
     */
    function getEthUsdPair() internal view returns (uint256) {
        bytes32 pair = _medianizer.read();
        return uint256(pair);
    }
}