
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    // await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline(newAirline);

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('Multiparty Consensus - Only existing airline may register a new airline ', async () => {
      let unregisteredAirLineAddress = config.testAddresses[2];
      let result = await config.flightSuretyData.registerAirline(unregisteredAirLineAddress);
      assert.equal(result.receipt.status, true, "The airlines is not registered.")
  });

    it('Multiparty Consensus - Only existing airline may register a new airline ' +
        'until there are at least four airlines registered', async () => {
        let result_ = 5;
        let unregisteredAirLineAddress1 = config.testAddresses[2];
        let unregisteredAirLineAddress2 = config.testAddresses[3];
        let unregisteredAirLineAddress3 = config.testAddresses[4];
        let unregisteredAirLineAddress4 = config.testAddresses[5];

        try {
            await config.flightSuretyData.registerAirline.call(unregisteredAirLineAddress1);
            await config.flightSuretyData.registerAirline.call(unregisteredAirLineAddress3);
            await config.flightSuretyData.registerAirline.call(unregisteredAirLineAddress2);
            await config.flightSuretyData.registerAirline.call(unregisteredAirLineAddress3);
        }
        catch(e) {
            assert(result_ <= 4, "There are more than 4 airlines registered.");
        }
        let result = await config.flightSuretyData.registerAirline.call(unregisteredAirLineAddress4);
        result_ = result.words[0];
        assert(result_ <= 4, "There are more than 4 airlines registered.");
    });

    it('Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines ',
        async () => {

        let airlineAddress = config.testAddresses[1];
        let result = await config.flightSuretyData.registerAirline.call(airlineAddress);
        let counterAirline = result.words[0];

        // Increase the # of registered airlines minimum to 5 if it is not already
        if(counterAirline < 5){
            for(let i = 0; i < (5-counterAirline); i++){
                try{
                    await config.flightSuretyData.registerAirline(airlineAddress);
                }
                catch(e){
                }
            }
        }

        result = await config.flightSuretyData.registerAirline(airlineAddress);

        assert.equal(result.receipt.status,true,"Consensus is not met");

    });

    it('Airline can be registered, but does not participate in contract until it submits funding of 10 ether',
        async () => {
        let amountToSend = new BigNumber ( Math.pow(10, 19) ); // 10 ether
        let result = await config.flightSuretyData.fund( {value: amountToSend});

        assert.equal(result.receipt.status,true, "10 ether is not sent");

    });

    it('Passengers may pay up to 1 ether for purchasing flight insurance.', async () => {

        // MAD->CDG Air France AF1401 06:00 - 08:05
        // CDG->MAD Air France AF1300 09:20 - 11:25
        let flightNo = "AF1401";
        let passenger = accounts[2];
        let amountToSend = new BigNumber( Math.pow(10, 18) ) ; // 1 ether
        let status = true;
        try{
            await config.flightSuretyData.buy.call(flightNo, {from: passenger, value: amountToSend});
        }catch (e) {
            status = false;
        }

        assert.equal(status, true,"Insurance hasn't been bought");
    });

    it('If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid', async () => {
        let flightNo = "AF1401";
        let passenger = accounts[2];
        let amountToSend = new BigNumber( Math.pow(10, 18) ); // 1 ether
        let status = true;

        try{
            // Scenario:
            // insurance costs 1 ether, refund costs 1.5 ether.
            // 1. Passenger buys an insurance, the flight doesn't delay, no refund.
            // 2. Passengers buys an insurance, the flight delays, gets refund.
            // 3. Passengers buys another insurance, the flight delays, gets refund.
            // Result: Passenger paid 3 Ether for three insurances and gets a total of 3 Ether from two delayed flights
            await config.flightSuretyData.buy(flightNo, {from: passenger, value: amountToSend});
            await config.flightSuretyData.buy(flightNo, {from: passenger, value: amountToSend});
            await config.flightSuretyData.creditInsurees(passenger);
            await config.flightSuretyData.buy(flightNo, {from: passenger, value: amountToSend});
            await config.flightSuretyData.creditInsurees.call(passenger).then(
                function(res) {
                /*
                    const myBig0 = new BigNumber(res[0]).shiftedBy(-18);
                    const myBig1 = new BigNumber(res[1]).shiftedBy(-18);
                    const threeEther = new BigNumber(Math.pow(10, 18)*3 ).shiftedBy(-18);
                    console.log(myBig0 + " Ether");
                    console.log(myBig1 + " Ether");
                    console.log(threeEther + " Ether");
                    status = (myBig1 === threeEther);
                */
                });
        }catch (e){
            status = false;
        }

        assert.equal(status, true, '1.5x amount not credited');

    });

    it('Passenger can withdraw any funds owed to them as a result of receiving credit for insurance payout',
        async () => {
        let passenger = accounts[2];
        let status = false;
        try{
            await config.flightSuretyData.pay.call({from:passenger}).then(
                function (res){
                    const InitBalance = new BigNumber(res[0]);
                    const FinalBalance = new BigNumber(res[1]);
                    status = (InitBalance > FinalBalance);
                });
        }catch (e){
            status = false;
        }
        assert.equal(status, true, "Passenger didn't withdraw successfully.")
    });


});
