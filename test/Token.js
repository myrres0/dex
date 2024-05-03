const { expect } = require("chai");

describe("Token", function () {
  let owner;
  let addr1;
  let Token;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    const TokenFactory = await ethers.getContractFactory("Token");
    Token = await TokenFactory.deploy();
    await Token.deployed();
  });

  it("should have correct name and symbol", async function () {
    expect(await Token.name()).to.equal("loveFaceBook");
    expect(await Token.symbol()).to.equal("LFB");
  });

  it("should allow minting by owner", async function () {
    await Token.connect(owner).mint(1000);
    expect(await Token.balanceOf(await owner.getAddress())).to.equal(1000);
  });

  it("should not allow minting when disabled", async function () {
    await Token.connect(owner).disable_mint();
    await expect(Token.connect(owner).mint(1000)).to.be.revertedWith("Minting is disabled");
  });

  it("should not allow minting by non-owner", async function () {
    await expect(Token.connect(addr1).mint(1000)).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("should allow disabling minting by owner", async function () {
    await Token.connect(owner).disable_mint();
    expect(await Token.getCanMint()).to.equal(false);
  });

  it("should not allow disabling minting by non-owner", async function () {
    await expect(Token.connect(addr1).mint(1000)).to.be.revertedWith("Ownable: caller is not the owner");
  });

});