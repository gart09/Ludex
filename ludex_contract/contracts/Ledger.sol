// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PriceTable.sol";
import "./Utils.sol";

contract Ledger is ERC721, Ownable {

    using Utils for string;

    struct Purchase 
    {
        uint256 tokenID;
        uint32 itemID;
        address owner;
        uint256 timestamp;
    }

    struct FeeRateLogEntry 
    {
        uint256 timestamp;
        uint16 feeRatePermyriad;
    }

    uint256 tokenIDCounter;
    FeeRateLogEntry[] feeRateLog;

    PriceTable priceTable;

    mapping (uint256 => Purchase) purchases;

    constructor (
        uint16 feeRatePermyriad
    ) 
        ERC721("Ledger", "LEDG") 
        Ownable(msg.sender) 
    {
        tokenIDCounter = 0;
        feeRateLog.push(FeeRateLogEntry(block.timestamp, feeRatePermyriad));
        priceTable = new PriceTable(msg.sender);
    }
   
    function buyGame (
        uint32 itemID,
        string calldata tokenName
    ) 
        external
        returns (uint256)
    {
        require (
            priceTable.sellers(itemID) != address(0),
            "There's no item registered with given ID");

        IERC20 payToken = 
            IERC20(priceTable.paymentChannels(tokenName.toHash()));

        uint256 price = 
            priceTable.askPriceOfItemIn(itemID, tokenName);

        uint256 allowance = payToken.allowance(msg.sender, address(this));
        require(
            allowance >= price,
            "Allowance was not enough");
        
        uint256 timestampItemAdd = 
            priceTable.timestampsItemAdd(itemID);
        uint16 feeRatePermyriad = feeRateLog[0].feeRatePermyriad;
        for (uint256 i = 1; i < feeRateLog.length; i++)
        {
            if (timestampItemAdd > feeRateLog[i].timestamp)
            {
                feeRatePermyriad = feeRateLog[i].feeRatePermyriad;
            }
            else
            {
                break;
            }
        }

        uint256 ownerFee = price / 10000 * feeRatePermyriad;

        payToken.transferFrom(msg.sender, address(this), price - ownerFee);
        payToken.transferFrom(msg.sender, address(owner()), ownerFee);

        tokenIDCounter = tokenIDCounter + 1;
        Purchase memory purchase = 
            Purchase(
                tokenIDCounter,
                itemID,
                msg.sender,
                block.timestamp
            );
        purchases[purchase.tokenID] = purchase;
        _safeMint(msg.sender, purchase.tokenID);

        return purchase.tokenID;       
    }
}