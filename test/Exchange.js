const { expect } = require("chai");

describe("TokenExchange", function () {
  let TokenExchange;
  let tokenExchange;
  let Token;
  let token;

  let owner;
  let addr1;
  let addr2;
  let addr3;
  let addrs;

  before(async function () {
    TokenExchange = await ethers.getContractFactory("TokenExchange");
    Token = await ethers.getContractFactory("Token");

    [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

    token = await Token.deploy();
    await token.deployed();
    await token.connect(owner).mint(2000n * 10n ** 18n);

    tokenExchange = await TokenExchange.deploy();
    await tokenExchange.deployed();

    token.connect(owner).approve(tokenExchange.address, 20000n * 10n ** 18n);
    // Initialize the pool with some tokens
    await tokenExchange.connect(owner).createPool(1000n * 10n ** 18n, {value: 1000n * 10n ** 18n});
  });
  
//--------------------------------------------------------------------------------------------------------------------------------------------------//
//                                                     SWAP ETH FOR TOKENS                                                                          //                             
//--------------------------------------------------------------------------------------------------------------------------------------------------//
  it("should swap ETH for Tokens", async function () {
    const initialEthBalance = await addr1.getBalance();
    //console.log("Initial ETH Balance: ", initialEthBalance.toString());
    const ethAmount = ethers.utils.parseEther("0.000000000000001"); // 1000 wei

    // Approve the contract to spend ETH
    await token.connect(addr1).approve(tokenExchange.address, ethAmount);

    // Swap ETH for Tokens
    const token_rate = await tokenExchange.connect(addr1).getExchangeRateForEth();
    await tokenExchange.connect(addr1).swapETHForTokens(5, { value: ethAmount }); 
    
    const minTokensRate = BigInt(token_rate) * 95n / 100n; // 5% slippage
    const minTokens = BigInt(ethAmount) * BigInt(minTokensRate) / 10n ** 8n; // 1 eth -> min 0.95 token

    // Check if Tokens were received
    const tokenBalance = await token.balanceOf(addr1.address);
    expect(tokenBalance).to.be.gt(BigInt(minTokens)); // greater than 950(because of slippage pct)

    // Check if ETH was deducted from the user
    const finalEthBalance = await addr1.getBalance();
    expect(finalEthBalance).to.be.lt(initialEthBalance); // ETH balance reduced
  });

  it("should not allow swapping ETH for Tokens if msg.value = 0", async function () {
    let approve = await token.connect(addr1).approve(tokenExchange.address, 1000000000000000n);
    await expect(tokenExchange.connect(addr1).swapETHForTokens(
      2)).to.be.revertedWith("ETH value must be greater than 0");
  });

  it("should revert if token_reserve smaller than amount of tokens to be swapped", async function () {
    const ethAmount = ethers.utils.parseEther("2000"); 

    // Approve the contract to spend ETH
    await token.connect(addr2).approve(tokenExchange.address, ethAmount);

    await expect(tokenExchange.connect(addr2).swapETHForTokens(
      30, { value: ethAmount })).to.be.revertedWith("not enough eth in contract");
  });

  it("should allow multiple addresses to swap ETH for Tokens simultaneously", async function () {
    const initialEthBalanceAddr1 = await addr1.getBalance();
    const initialEthBalanceAddr2 = await addr2.getBalance();

    const ethAmount = ethers.utils.parseEther("0.000000000000001"); // 1000 wei

    // Approve the contract to spend ETH for both addresses
    await token.connect(addr1).approve(tokenExchange.address, ethAmount);
    await token.connect(addr2).approve(tokenExchange.address, ethAmount);

    // Swap ETH for Tokens for both addresses simultaneously
    const swapTx1 = tokenExchange.connect(addr1).swapETHForTokens(5, { value: ethAmount });
    const swapTx2 = tokenExchange.connect(addr2).swapETHForTokens(5, { value: ethAmount });

    // Wait for both transactions to complete
    await Promise.all([swapTx1, swapTx2]);

    // Check if Tokens were received for both addresses
    const tokenBalanceAddr1 = await token.balanceOf(addr1.address);
    //console.log("Token Balance Addr1: ", tokenBalanceAddr1.toString());
    const tokenBalanceAddr2 = await token.balanceOf(addr2.address);
   // console.log("Token Balance Addr2: ", tokenBalanceAddr2.toString());
    expect(tokenBalanceAddr1).to.be.gt(0); // Tokens received for address 1
    expect(tokenBalanceAddr2).to.be.gt(0); // Tokens received for address 2

    // Check if ETH was deducted from both addresses
    const finalEthBalanceAddr1 = await addr1.getBalance();
    const finalEthBalanceAddr2 = await addr2.getBalance();
    expect(finalEthBalanceAddr1).to.be.lt(initialEthBalanceAddr1); // ETH balance reduced for address 1
    expect(finalEthBalanceAddr2).to.be.lt(initialEthBalanceAddr2); // ETH balance reduced for address 2
  });

//--------------------------------------------------------------------------------------------------------------------------------------------------//
//                                                     SWAP TOKENS FOR ETH                                                                          //                             
//--------------------------------------------------------------------------------------------------------------------------------------------------//

  it("should swap Tokens for ETH", async function () {
    const initialEthBalance = await addr1.getBalance();
    const initialTokenBalance = await token.balanceOf(addr1.address);
    const tokenAmount = 1000n; // 1 token

    // Approve the contract to spend Tokens
    await token.connect(addr1).approve(tokenExchange.address, tokenAmount);

    // Swap Tokens for ETH
    const eth_rate = await tokenExchange.connect(addr1).getExchangeRateForToken();
    await tokenExchange.connect(addr1).swapTokensForETH(tokenAmount, 10);

    const minEthRate = BigInt(eth_rate) * 95n / 100n; // 5% slippage
    const minEth = BigInt(tokenAmount) * BigInt(minEthRate) / 10n ** 18n; // 1 token -> min 0.95 eth

    // Check if Tokens were deducted from the user
    const finalTokenBalance = await token.balanceOf(addr1.address);
    expect(finalTokenBalance).to.be.lt(initialTokenBalance); // Tokens balance reduced
  });

  it("should not allow swapping tokens if amoutTokens = 0", async function () {
    let approve = await token.connect(addr1).approve(tokenExchange.address, 1000000000000000n);
    await expect(tokenExchange.connect(addr1).swapTokensForETH(
      0,5)).to.be.revertedWith("amountTokens should be greater than 0");
  });

  it("should not allow to swap if user dont have enough tokens", async function () {
    let approve = await token.connect(addr1).approve(tokenExchange.address, 1000000000000000n);
    await expect(tokenExchange.connect(addr1).swapTokensForETH(
      1000000000000000n,5)).to.be.revertedWith("not enough tokens to swap");
  });

  it("should not allow to swap if max exchange rate is greater than the current exchange rate", async function () {
    let approve = await token.connect(addr1).approve(tokenExchange.address, 1000000000000000n);
    await expect(tokenExchange.connect(addr1).swapTokensForETH(
      5,10000000000)).to.be.revertedWith("max_echange_rate is greater than curr rate");
  });


//--------------------------------------------------------------------------------------------------------------------------------------------------//
//                                                     ADD LIQUIDITY                                                                        //                             
//--------------------------------------------------------------------------------------------------------------------------------------------------//

  it("should revert if user does not send eth to add liquidity", async function () {
    await expect(tokenExchange.connect(addr1).addLiquidity(1000000000n, 1000)).to.be.revertedWith(
      "Need eth to add liquidity.");
  });

  it("should revert if user does not have enough tokens to add liquidity", async function () {
    await expect(tokenExchange.connect(addr1).addLiquidity(1000000000n, 0, { value: 1000000000n })).to.be.revertedWith(
      "Not have enough tokens to add liquidity.");
  });

  it("should be successful if user has enough tokens and eth to add liquidity", async function () {
    const ethAmount = ethers.utils.parseEther("0.0000000000000001"); // 100 wei

    await token.connect(addr2).approve(tokenExchange.address, 1000000000n);
    await tokenExchange.connect(addr2).addLiquidity(1000000000n, 0, { value: ethAmount });
  });
  
  it("should revert as minEthRate is greater than the maxExchange rate in addLiquidity", async function () {
    await expect(tokenExchange.connect(addr3).addLiquidity(1, 1000000000000,  { value: 10 })).to.be.revertedWith(
      "max_exchange_rate should be greater than min_exchange_rate");
  });

  it("should revert as minEthRate is greater than the current rate in addLiquidity", async function () {
    await expect(tokenExchange.connect(addr1).addLiquidity(10000000000001, 1000000000000,  { value: 10 })).to.be.revertedWith(
      "current rate is too low");
  });

  it("should revert as maxEthRate is lower than the current rate in addLiquidity", async function () {
    await expect(tokenExchange.connect(addr1).addLiquidity(1000, 1,  { value: 10 })).to.be.revertedWith(
      "current rate is too high");
  });
  



//--------------------------------------------------------------------------------------------------------------------------------------------------//
//                                                     REMOVE LIQUIDITY                                                                        //                             
//--------------------------------------------------------------------------------------------------------------------------------------------------//

  it("should revert if user does not have enough liquidity to remove", async function () {
    await expect(tokenExchange.connect(addr1).removeLiquidity(
      1000000000n, 10000000000, 10)).to.be.revertedWith(
      "Sender have not enough liquidity to remove.");
  });
  it("should revert if amountWei is 0", async function () {
    await expect(tokenExchange.connect(addr1).removeLiquidity(
      0, 1000000000000, 10)).to.be.revertedWith(
      "Amount of ETH cannot be 0 to remove liquidity.");
  });

  it("should be successful if user has enough liquidity to remove", async function () {
    const ethAmount = ethers.utils.parseEther("0.0000000000000001"); // 100wei

   // console.log("token balance of addr1: ", await token.balanceOf(addr1.address));

    await token.connect(addr1).approve(tokenExchange.address, 1000000000n);
    await tokenExchange.connect(addr1).addLiquidity(1000000000n, 0, { value: ethAmount });
    const tokenOnAccount = await token.balanceOf(addr1.address);
    await tokenExchange.connect(addr1).removeLiquidity(ethAmount/2, 10000000000, 10);

    const newTokenBalance = await token.balanceOf(addr1.address);
    expect(newTokenBalance).to.be.gt(tokenOnAccount); //tokens received
  });
  it("should revert as minEthRate is greater than the maxExchange rate in removeLiquidity", async function () {
    await expect(tokenExchange.connect(addr3).removeLiquidity(1, 1, 1000000000000)).to.be.revertedWith(
      "max_exchange_rate should be greater than min_exchange_rate");
  });
  it("should revert as minEthRate is greater than the current rate in removeLiquidity", async function () {
    await expect(tokenExchange.connect(addr1).removeLiquidity(1, 10000000000001, 1000000000000)).to.be.revertedWith(
      "current rate is too low");
  });
  it("should revert as maxEthRate is lower than the current rate in removeLiquidity", async function () {
    await expect(tokenExchange.connect(addr1).removeLiquidity(1, 1000, 1)).to.be.revertedWith(
      "current rate is too high");
  });
  
//--------------------------------------------------------------------------------------------------------------------------------------------------//
//                                                     REMOVE ALL LIQUIDITY                                                                        //                             
//--------------------------------------------------------------------------------------------------------------------------------------------------//

it("should revert if user does not have enough liquidity to remove", async function () {

  await expect(tokenExchange.connect(addr3).removeAllLiquidity(1000000000, 1)).to.be.revertedWith(
    "Sender have no liquidity to remove.");
});

it("should revert as minEthRate is greater than the maxExchange rate in removeAllLiquidity ", async function () {
  await expect(tokenExchange.connect(addr3).removeAllLiquidity(1, 1000000000000)).to.be.revertedWith(
    "max_exchange_rate should be greater than min_exchange_rate");
});
it("should revert as minEthRate is greater than the current rate in removeAllLiquidity", async function () {
  await expect(tokenExchange.connect(addr1).removeAllLiquidity(10000000000001, 1000000000000)).to.be.revertedWith(
    "current rate is too low");
});
it("should revert as maxEthRate is lower than the current rate in removeAllLiquidity", async function () {
  await expect(tokenExchange.connect(addr1).removeAllLiquidity(1000, 1)).to.be.revertedWith(
    "current rate is too high");
});

it("successful if user has enough liquidity to remove", async function () {
  const ethAmount = ethers.utils.parseEther("0.0000000000000001"); // 100wei

  await token.connect(addr1).approve(tokenExchange.address, 1000000000n);
  await tokenExchange.connect(addr1).addLiquidity(1000000000n, 0, { value: ethAmount });
  const tokenOnAccount = await token.balanceOf(addr1.address);
  await tokenExchange.connect(addr1).removeAllLiquidity(1000000000, 1);
  const newTokenBalance = await token.balanceOf(addr1.address);
  expect(newTokenBalance).to.be.gt(tokenOnAccount); //tokens received
});



//--------------------------------------------------------------------------------------------------------------------------------------------------//
//                                      Simulating multithreading(slippage pct working correctly)                                                                 //
//--------------------------------------------------------------------------------------------------------------------------------------------------//


/**
 * @notice In this test one transaction at a time, so the rate would change, 
 * but this is just a simulation of an example where 2 swaps would be run at the same time 
 * and then one would affect the rate and the second transaction would not go through
*/
it("should not allow to swap if rate was changed too much with other address", async function () {
  const initialEthBalanceAddr1 = await addr1.getBalance();
  const initialEthBalanceAddr2 = await addr2.getBalance();

  const ethAmount = ethers.utils.parseEther("0.00001");

  // Approve the contract to spend ETH for both addresses
  await token.connect(addr1).approve(tokenExchange.address, ethAmount);
  await token.connect(addr2).approve(tokenExchange.address, ethAmount);
  
  const token_rate = await tokenExchange.connect(addr1).getExchangeRateForEth();

  // Swap ETH for Tokens for both addresses simultaneously
  const swapTx1 = tokenExchange.connect(addr1).swapETHForTokens(50, { value: ethAmount });

  await swapTx1;
  await expect(tokenExchange.connect(addr2).swapTokensForETH(100, token_rate)).to.be.revertedWith(
    "max_echange_rate is greater than curr rate");
  });


});