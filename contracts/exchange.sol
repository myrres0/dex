// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import './token.sol';
import "hardhat/console.sol";


contract TokenExchange is Ownable {
    string public exchange_name = 'ETH';

    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;   // TODO: paste token contract address here
    Token public token = Token(tokenAddr);

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private wei_reserves = 0;

    // Mapping of liquidity providers to their liquidity pool
    mapping(address => uint) private lps;

    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;

    // liquidity rewards
    uint private swap_fee_numerator = 3;
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    // variable for percentage calculation
    uint percentageConverter = 10**25;

    constructor() {}


    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        onlyOwner
    {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require (token_reserves == 0, "Token reserves was not 0");
        require (wei_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        wei_reserves = msg.value;
        k = token_reserves * wei_reserves;

        lps[msg.sender] = percentageConverter;
        lp_providers.push(msg.sender);

        console.log("token_reserves: ", token_reserves); // debug
        console.log("wei_reserves: ", wei_reserves); // debug
    }

    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(index < lp_providers.length, "specified index is larger than the number of lps");
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // function to find the index of an address in the lp_providers array
    function indexOf(address _address) private view returns (uint) {
        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] == _address) {
                return i;
            }
        }
        // return an invalid index to indicate 'not found'
        return lp_providers.length;
    }

    //check rates that user provided
    modifier initCheck() {

        // require pool does not exist yet:
        require (token_reserves > 0, "Token reserves are 0.");
        require (wei_reserves > 0, "WEI reserves are 0.");
        _;
    }

    modifier slippageRateCheck(uint max_exchange_rate, uint min_exchange_rate) {
        // max_exchange_rate >= than min_exchange_rate check
        require(max_exchange_rate >= min_exchange_rate, "max_exchange_rate should be greater than min_exchange_rate");

        // rate frame check
        require(getExchangeRateForToken() <= max_exchange_rate, "current rate is too high");
        require(getExchangeRateForToken() >= min_exchange_rate, "current rate is too low");
        _;
    }

    function changeFee(uint new_swap_fee_numerator, uint new_swap_fee_denominator) public onlyOwner {

        require(new_swap_fee_numerator > 0, "swap fee numerator should be greater than 0");
        require(new_swap_fee_numerator <= new_swap_fee_denominator, "swap fee numerator should be less than or equal to swap fee denominator");

        swap_fee_numerator = new_swap_fee_numerator;
        swap_fee_denominator = new_swap_fee_denominator;
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    /* ========================= Liquidity Provider Functions =========================  */

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.

    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
        initCheck()
        slippageRateCheck(max_exchange_rate, min_exchange_rate)
    {
//         Algorithm:
//         1. Check whether init method was called
//         2. Make a slippage check
//         3. Check if the amount of tokens is greater than 0
//         4. Check if the user has enough tokens to add liquidity
//         5. Make a token transfer
//         6. Check if the user is already in the liquidity providers array if no add his/her address
//         7. Cycle through the liquidity providers and update their percentages
//         8. Update reserves
//         9. Update k

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to add liquidity.");

        // how much token sender need to have on a balance
        uint tokenNeed= msg.value * token_reserves / wei_reserves;

        // check if the amount of tokens is greater than 0
        require(tokenNeed > 0, "msg.value is too low to add liquidity.");

        // check if the user has enough tokens to add liquidity
        uint tokenSupply = token.balanceOf(msg.sender);
        require(tokenNeed <= tokenSupply, "Not have enough tokens to add liquidity.");

        // make a transfer
        token.transferFrom(msg.sender, address(this), tokenNeed);

        // check if the user is already in the liquidity providers array
        // if not add his/her address
        if(lps[msg.sender] == 0) {
            lp_providers.push(msg.sender);
        }

        // cycle through the liquidity providers and update their percentages
        for (uint i = 0; i < lp_providers.length; i++) {
            address lp = lp_providers[i];

            uint lpPercentage = lps[lp];
            uint lpWeiAmount = wei_reserves * lpPercentage / percentageConverter;

            console.log("iterating through lps: ", i, "\n"); // debug
            console.log("   address: ", lp); // debug
            console.log("   lpWeiAmount: ", lpWeiAmount); // debug
            console.log("   lpPercentage: ", lpPercentage, "\n"); // debug

            if (lp == msg.sender) {
                lpWeiAmount += msg.value;
                console.log("   lpWeiAmount (NEW): ", lpWeiAmount); // debug
            }

            lps[lp] = lpWeiAmount * percentageConverter / address(this).balance;
            console.log("   new lpPercentage: ", lps[lp], "\n\n"); // debug
        }

        // update reserves
        token_reserves = token.balanceOf(address(this));
        wei_reserves = address(this).balance;

        // update k
        k = token_reserves * wei_reserves;
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountWEI, uint max_exchange_rate, uint min_exchange_rate)
        public
        payable
        initCheck()
        slippageRateCheck(max_exchange_rate, min_exchange_rate)
    {
//         Algorithm:
//         1. Check whether init method was called
//         2. Make a slippage check
//         3. Check if the amount of ETH is greater than 0
//         4. Check if the user has enough liquidity to remove
//         5. Calculate how much token sender will get
//         6. Check if the user is going to remove all his/her liquidity if yes remove him/her from the list
//         7. If there is only one liquidity provider left, set his/her percentage to 100%
//         8. If there are more than one liquidity providers, cycle through the liquidity providers and update their percentages
//         9. Update reserves
//         10. Update k

        // amountETH cannot be 0
        require (amountWEI > 0, "Amount of ETH cannot be 0 to remove liquidity.");

        // is enough liquidity to remove
        uint senderPercentage = lps[msg.sender];
        uint senderWeiAmount = wei_reserves * senderPercentage / percentageConverter;
        require(senderWeiAmount >= amountWEI, "Sender have not enough liquidity to remove.");

        // calculate how much token sender will get
        uint tokenAmount = amountWEI * token_reserves / wei_reserves;
        require(tokenAmount > 0, "amountWEI is too low to remove liquidity.");

        // check if sender are not going to remove all liquidity
        require(wei_reserves - amountWEI > 0, "Cannot to remove liquidity to 0.");
        require(token_reserves - tokenAmount > 0, "Cannot to remove liquidity to 0.");

        // make transfers
        token.transfer(msg.sender, tokenAmount);
        (bool sent, ) = payable(msg.sender).call{value: amountWEI}("");

        // check if eth transfer was successful
        require(sent, "ETH transfer failed");

        // remove liquidity provider from the list if he/she is going to remove all his/her liquidity
        if (senderWeiAmount - amountWEI == 0) {
            removeLP(indexOf(msg.sender));
            lps[msg.sender] = 0;
        }

        // if there is only one liquidity provider left, set his/her percentage to 100%
        if (lp_providers.length == 1) {
            lps[lp_providers[0]] = percentageConverter;
        }
        // if there are more than one liquidity providers
        else {
            // cycle through the liquidity providers and update their percentages
            for (uint i = 0; i < lp_providers.length; i++) {
                address lp = lp_providers[i];

                uint lpPercentage = lps[lp];
                uint lpWeiAmount = wei_reserves * lpPercentage / percentageConverter;

                console.log("iterating through lps: ", i, "\n"); // debug
                console.log("   address: ", lp); // debug
                console.log("   lpWeiAmount: ", lpWeiAmount); // debug
                console.log("   lpPercentage: ", lpPercentage, "\n"); // debug

                if (lp == msg.sender) {
                    lpWeiAmount -= amountWEI;
                    console.log("   lpWeiAmount (NEW): ", lpWeiAmount); // debug
                }

                lps[lp] = lpWeiAmount * percentageConverter / address(this).balance;
                console.log("   new lpPercentage: ", lps[lp], "\n\n"); // debug
            }
        }

        // update reserves
        token_reserves = token.balanceOf(address(this));
        wei_reserves = address(this).balance;

        // update k
        k = token_reserves * wei_reserves;
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
        initCheck()
        slippageRateCheck(max_exchange_rate, min_exchange_rate)
    {
//         Algorithm:
//         1. Check whether init method was called
//         2. Make a slippage check
//         3. Check if the user has enough liquidity to remove
//         4. Calculate how much token sender will get
//         5. Remove him/her from the list
//         6. If there is only one liquidity provider left, set his/her percentage to 100%
//         7. If there are more than one liquidity providers, cycle through the liquidity providers and update their percentages
//         8. Update reserves
//         9. Update k


        // is enough liquidity to remove?
        uint senderPercentage = lps[msg.sender];
        uint senderWeiAmount = wei_reserves * senderPercentage / percentageConverter;
        require(senderWeiAmount > 0, "Sender have no liquidity to remove.");

        // calculate how much token sender will get
        uint tokenAmount = token_reserves * senderPercentage / percentageConverter;

        // check if sender are not going to remove all liquidity
        require(wei_reserves - senderWeiAmount > 0, "Cannot remove liquidity to 0.");
        require(token_reserves - tokenAmount > 0, "Cannot remove liquidity to 0.");

        // make transfers
        token.transfer(msg.sender, tokenAmount);
        (bool sent, ) = payable(msg.sender).call{value: senderWeiAmount}("");

        // check if eth transfer was successful
        require(sent, "ETH transfer failed");

        // remove liquidity provider from the list and set his/her percentage to 0
        removeLP(indexOf(msg.sender));
        lps[msg.sender] = 0;

        // if there is only one liquidity provider left, set his/her percentage to 100%
        if (lp_providers.length == 1) {
            lps[lp_providers[0]] = percentageConverter;
        }
        // if there are more than one liquidity providers
        else {
            // cycle through the liquidity providers and update their percentages
            for (uint i = 0; i < lp_providers.length; i++) {
                address lp = lp_providers[i];

                uint lpPercentage = lps[lp];
                uint lpWeiAmount = wei_reserves * lpPercentage / percentageConverter;

                console.log("iterating through lps: ", i, "\n"); // debug
                console.log("   address: ", lp); // debug
                console.log("   lpWeiAmount: ", lpWeiAmount); // debug
                console.log("   lpPercentage: ", lpPercentage, "\n"); // debug

                lps[lp] = lpWeiAmount * percentageConverter / address(this).balance;
                console.log("   new lpPercentage: ", lps[lp], "\n\n"); // debug
            }
        }

        // update reserves
        token_reserves = token.balanceOf(address(this));
        wei_reserves = address(this).balance;

        // update k
        k = token_reserves * wei_reserves;
    }

    /***  Define additional functions for liquidity fees here as needed ***/



    /* ========================= Swap Functions =========================  */

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
        function swapTokensForETH(uint amountTokens, uint max_exchange_rate)
        external
        payable checkRate(max_exchange_rate, 0)
    {
//         Algorithm:
//         1. Check if amountTokens is greater than 0
//         2. Check if user have enough tokens
//         3. Transfer tokens to the contract
//         4. Calculate amount of ETH
//         5. Check if contract have enough ETH
//         6. Check if amount > max_exchange_rate
//         7. Transfer ETH to user
//         8. Update reserves

        require(amountTokens > 0, "amountTokens should be greater than 0"); //check if amountTokens is greater than 0

        require(token.balanceOf(msg.sender) >= amountTokens, "not enough tokens to swap"); //check if user have enough tokens
        uint amountETH = getAmountOfTokens(amountTokens, token_reserves, wei_reserves);

        uint currRate = countExchangeRate(token_reserves, wei_reserves);

        require(wei_reserves > amountETH, "not enough eth in contract to swap"); //check if contract have enough eth
        console.log("currRate: ", currRate); // debug
        console.log("max_exchange_rate: ", max_exchange_rate); // debug
        require(currRate >= max_exchange_rate, "max_echange_rate is greater than curr rate"); //check if amount > max_exchange_rate
        //require(amountETH > ((max_exchange_rate*amountTokens)/10**8), "amountTokens is greater than max_exchange_rate tokens"); //check if amount > max_exchange_rate

        //transfer tokens to contract
        token.transferFrom(msg.sender, address(this), amountTokens);

        //send eth to user
        (bool sent, ) = payable(msg.sender).call{value: amountETH}("");
        require(sent, "ETH transfer failed");
        //payable(msg.sender).transfer(amountETH);

        //update reserves
        wei_reserves-= amountETH;
        token_reserves = token.balanceOf(address(this));
    }

    function getAmountOfTokens(uint amount, uint input_reserves, uint output_reserves) public view returns(uint) {
        require(input_reserves > 0 && output_reserves > 0, "Invalid reserves");
        //count amount of tokens including fee so *97
        uint amountWithFee = amount * (swap_fee_denominator - swap_fee_numerator); // 3% - odmena
        uint numerator = amountWithFee * output_reserves;

        //we need to have proportion 97/100 so multiply denominator by 100
        uint denominator = (input_reserves*swap_fee_denominator) + amountWithFee;

        //return amount of tokens we need to send
        return numerator/denominator;
    }


    function countExchangeRate(uint input_reserves, uint output_reserves) public pure returns(uint) {
        //multiply by 10**8 to avoid floating point numbers
        return (input_reserves * 10**8) / output_reserves;
    }

    function getExchangeRateForEth() public view returns(uint) {
        return countExchangeRate(wei_reserves, token_reserves);
    }

    function getExchangeRateForToken() public view returns(uint) {
        return countExchangeRate(token_reserves, wei_reserves);
    }


    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate)
        external
        payable checkRate(max_exchange_rate, 0)
    {
//         Algorithm:
//         1. Check if user send eth
//         2. Check if contract have enough tokens
//         3. Calculate amount of tokens
//         4. Calculate current rate
//         5. Check if current rate is greater than max exchange rate
//         6. Check if contract has enough tokens
//         7. Send tokens to user
//         8. Update reserves

        //check if user send eth
        require(msg.value > 0, "ETH value must be greater than 0");

        //check if contract have enough tokens
        require(msg.value <= wei_reserves, "not enough eth in contract");

        //calculate amount of tokens
        uint amountToken = getAmountOfTokens(msg.value, wei_reserves, token_reserves);

        //calculate current rate
        uint currRate = countExchangeRate(wei_reserves,token_reserves);

        //current rate should be greater than max exchange rate
        require(currRate >= max_exchange_rate, "max echange rate is greater than amount of tokens");
        // check if contract has enough tokens
        require(amountToken < token_reserves, "contract hasnt enought tokens");
       // require(amountToken > ((max_exchange_rate*msg.value)/10**8), "amountTokens is greater than max_exchange_rate tokens"); //check if amount > max_exchange_rate


        //send tokens to user
        token.transfer(msg.sender, amountToken);


        //update reserves
        wei_reserves+= msg.value;
        token_reserves = token.balanceOf(address(this));

    }

        //check rates that user provided
    modifier checkRate(uint max_exchange_rate, uint min_exchange_rate) {
        require(max_exchange_rate >= min_exchange_rate, "max_exchange_rate should be greater than min_exchange_rate");
        _;
    }
}