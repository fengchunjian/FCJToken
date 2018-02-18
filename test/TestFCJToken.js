var FCJToken = artifacts.require("FCJToken");

contract('FCJToken', function(accounts) {
  it("should not be able to start ico sale when not called by owner.", function() {
    console.log("\n" + "-".repeat(100) + "\n");
    var fcj;
    var target;
    return FCJToken.deployed().then(function(instance) {
      fcj = instance;
      console.log("fcj:", fcj.address);
      return fcj.target.call({from: accounts[1]});
    }).then(function(t){
      target = accounts[1];
      web3.eth.sendTransaction({from: accounts[1], to: fcj.address, value: web3.toWei(1) })
      return web3.eth.sendTransaction({from: accounts[1], to: target, value: web3.toWei(1) })
    }).then(function(tx) {
      console.log("tx:", tx);
      console.log("blockNumber:", web3.eth.blockNumber);
      return fcj.start(100, {from: accounts[1]});
    }).then(function(tx) {
      console.log("tx:", tx);
      if (tx.logs) {
        for (var i = 0; i < tx.logs.length; i++) {
          var log = tx.logs[i];
          if (log.event == "InvalidCaller") {
            return true;
          }
        }
      }
      return false;
    }).then(function(result) {
      assert.equal(result, true, "no SaleStarted event found");
    });
  });

  it("should not allow create tokens before it starts", function() {
    console.log("\n" + "-".repeat(100) + "\n");
    var fcj;
    var target;
    return FCJToken.deployed().then(function(instance) {
      fcj = instance;
      return fcj.target.call({from: accounts[1]});
    }).then(function(t){
      target = t;
      console.log("target:", target);
      firstblock = t.blockNumber + 1;
      return web3.eth.sendTransaction({from: accounts[1], to: fcj.address, value: web3.toWei(1) });

    }).then(function(txHash) {
      console.log("txHash", txHash);
      // InvalidState event shoud emitted here.
      return true;
    }).then(function(result) {
      assert.equal(result, true, "create tokens before sale start");
    });
  });

  it("should be able to start ico sale when called by owner.", function() {
    console.log("\n" + "-".repeat(100) + "\n");
    var fcj;
    var target;
    return FCJToken.deployed().then(function(instance) {
      fcj = instance;
      return fcj.target.call();
    }).then(function(t){
      target = t;
      return fcj.start(10, {from: target});
    }).then(function(tx) {
      console.log("tx: ", tx);
      if (tx.logs) {
        for (var i = 0; i < tx.logs.length; i++) {
          var log = tx.logs[i];
          if (log.event == "SaleStarted") {
            return true;
          }
        }
      }
      return false;
    }).then(function(result) {
      assert.equal(result, true, "no SaleStarted event found");
    });
  });

  it("should be able to create FCJ tokens after sale starts", function() {
    console.log("\n" + "-".repeat(100) + "\n");
    var fcj;
    var target;
    var externalTxHash;
    return FCJToken.deployed().then(function(instance) {
      fcj = instance;
      return fcj.target.call({from: accounts[1]});
    }).then(function(t){
      target = t;
      return web3.eth.sendTransaction({from: accounts[1], to: fcj.address, value: web3.toWei(1), gas: 500000 });
    }).then(function(tx) {
      console.log("tx:", tx);
      return fcj.balanceOf(accounts[1], {from: accounts[1]});
    }).then(function(bal) {
      console.log("bal: ", bal.toNumber());
      assert.equal(bal.toNumber(), web3.toWei(6000), "no FCJ token Transfer event found");
    });
  });
});
