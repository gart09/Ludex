// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Utils.sol";

contract PriceTable is Ownable {

    using Utils for string;
    using Utils for bytes;

    struct PaymentInfo 
    {
        bool assigned;
        int16 decimal;
        uint256 usdToToken;
    }

    struct PriceInfo 
    {
        string tokenName;
        uint256 tokenAmount;
    }

    string[] public storePaymentsIteration;
    mapping (bytes32 => PaymentInfo) public paymentInfoTable;
    mapping (bytes32 => address) public paymentChannels;

    mapping (uint32 itemID => uint256) public priceInUSD;
    mapping (uint32 itemID => uint256) public timestampsItemAdd;
    mapping (uint32 itemID => address) public sellers;
    mapping (address => mapping(string => bool)) public sellerPayments;
    mapping (address => uint8) sellerPaymentsNumber;

    constructor (address storeAddress) Ownable(storeAddress) {}

    function addPaymentChannel(
        string calldata channelName,
        address channelAddress
    )
        external
        onlyOwner
    {
        require(
            channelAddress != address(0),
            "Not a valid address");

        require(
            paymentChannels[channelName.toHash()] == address(0),
            "Token already exists ");

        paymentChannels[channelName.toHash()] = channelAddress;
        storePaymentsIteration.push(channelName);
    }

    function removePaymentChannels(
        string calldata channelName
    )
        external
        onlyOwner
    {
        delete paymentChannels[channelName.toHash()];

        bytes32 removedChannelNameHash = channelName.toHash();
        uint16 i;
        for (i = 0; i < storePaymentsIteration.length; i++)
        {
            bytes32 storePaymentHash = 
                storePaymentsIteration[i].toHash();
            if (removedChannelNameHash == storePaymentHash)
                break;
        }
        delete storePaymentsIteration[i];
    }

    function updateExchangeRate(
        string memory tokenName,
        int16 decimal,
        uint256 usdToToken
    )
        external
        onlyOwner
        returns (PaymentInfo memory)
    {
        bytes32 tokenNameHash = tokenName.toHash();
        PaymentInfo memory removal = paymentInfoTable[tokenNameHash];
        if (!removal.assigned)
        {
            storePaymentsIteration.push(tokenName);
        }

        paymentInfoTable[tokenNameHash] = 
            PaymentInfo(
                true,
                decimal,
                usdToToken
            );

        return removal;
    }

    function removePaymentChannel(
        string memory tokenName
    )
        external
        onlyOwner       
        returns (PaymentInfo memory)
    {
        bytes32 tokenNameHash = tokenName.toHash();
        PaymentInfo memory removal = paymentInfoTable[tokenNameHash];

        PaymentInfo memory defaultStruct; 
        paymentInfoTable[tokenNameHash] = defaultStruct;

        return removal;
    }


    function askPriceOfItemIn(
        uint32 itemID,
        string memory tokenName
    )
        public
        view
        returns (uint256)
    {
        uint256 priceUSD = priceInUSD[itemID];
        PaymentInfo storage exchangeRate = paymentInfoTable[tokenName.toHash()];
        
        require(exchangeRate.assigned, 
            string(abi.encodePacked(
                "There's no token assigned on the price table: \n\t",
                "Token Name: ", tokenName)));

        uint256 price = priceUSD * exchangeRate.usdToToken;
        for (uint16 i = 0; int16(i) < exchangeRate.decimal; i++)
        {
            price *= 10;
        }
        for (int16 i = 0; i > exchangeRate.decimal; i--)
        {
            price /= 10;
        }

        return price;
    }

    function getPriceInfoList (
        uint32 itemID
    )
        external
        view
        returns (PriceInfo[] memory)
    {

        require (
            sellers[itemID] != address(0),
            "Item was not registered");

        address seller = sellers[itemID];
        PriceInfo[] memory infoList = 
            new PriceInfo[](sellerPaymentsNumber[seller]);
        uint8 resultIdx = 0;

        for (uint256 i = 0; i < storePaymentsIteration.length; i++)
        {
            string storage tokenName = storePaymentsIteration[i];

            if (!sellerPayments[seller][tokenName])
                continue;

            uint256 tokenAmount = askPriceOfItemIn(itemID, tokenName);

            infoList[resultIdx] = PriceInfo(tokenName, tokenAmount);
        }
        
        return infoList;
    }

    modifier onlyActiveSeller ()
    {
        require(sellerPaymentsNumber[msg.sender] > 0);
        _;
    }

    function addItem(
        string calldata itemName,
        uint256 usdPrice,
        string[] calldata payments
    )
        external
        onlyActiveSeller
        returns (uint32)
    {
        uint32 itemID = 
            abi.encode(msg.sender, itemName).toFnv1aHash();

        require(
            sellers[itemID] == address(0),
            "There's an item already added for the pair of sender's address and item name");
       
        for (uint16 i = 0; i < payments.length; i++)
        {
            require(
                paymentInfoTable[payments[i].toHash()].assigned,
                "Invalid payment name given");
        }
        for (uint16 i = 0; i < payments.length; i ++)
        {
            sellerPayments[msg.sender][payments[i]] = true;
            sellerPaymentsNumber[msg.sender]++;
        }

        priceInUSD[itemID] = usdPrice;
        timestampsItemAdd[itemID] = block.timestamp;
        sellers[itemID] = msg.sender;

        return itemID;
    }

    function changeItemPrice (
        uint32 itemID,
        uint256 newUsdPrice
    )
        external
        onlyActiveSeller
        returns (uint256)
    {
        require(sellers[itemID] == msg.sender);

        uint256 prevPrice = priceInUSD[itemID];
        priceInUSD[itemID] = newUsdPrice;

        return prevPrice;
    }

    function addSellerPaymentChannel(
        string calldata tokenName
    )
        external
        onlyActiveSeller
    {
        require(
            !sellerPayments[msg.sender][tokenName],
            "Token already added as a payment channel");

        sellerPayments[msg.sender][tokenName] = true;
        sellerPaymentsNumber[msg.sender]++;
    }

    function removeSellerPaymentChannel(
        string calldata tokenName
    )
        external
        onlyActiveSeller
    {
        require(
            sellerPayments[msg.sender][tokenName],
            "Given token name is not payment channel of msg.sender"
        );

        sellerPayments[msg.sender][tokenName] = false;
        sellerPaymentsNumber[msg.sender]--;
    }

}