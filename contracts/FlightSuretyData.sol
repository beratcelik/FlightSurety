pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    uint256 counterAirline;                                             // The number of airlines registered
    uint256 regFee = 10 ether;                                          // Registration fee of an airline
    uint256 maxInsuranceFee = 1 ether;                                  // Maximum amount to be paid for an insurance

    struct Airline {                                                    // Create the struct 'Airline'
        bool isRegistered;                                              // True if the airline is registered
        bool isFunded;                                                  // True if the airline payed the fund
        uint256 balance;                                                // Balance of the airline
        address[] votes;                                                // Number of votes to accept the airline registered
    }

    struct Insurance {                                                  // Stores the purchased insurances
        uint256 paidAmount;                                             // Amount paid to get the insurance
        string flightNo;                                                // Flight no for the purchased insurance
        uint256 balance;                                                // Total sum of credited payments to the insuree
    }

    mapping(address => Airline) private airlines;                       // Create 'airlines' object to store if the airline is registered or not.
    mapping(address => Insurance) private insurances;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public {
        contractOwner = msg.sender;
        counterAirline = 0;
        registerTheFirstAirline(contractOwner);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the contract caller is a registered airline
    */
    modifier requireRegisteredAirline(){
        require(airlines[msg.sender].isRegistered == true,"Caller is not a registered airline");
        _;
    }

    /**
    * @dev Modifier that requires maximum 4 airlines registered
    */
    modifier requireFourOrLessAirlines(){
        require(counterAirline <= 4,"There are more that 4 airlines registered");
        _;
    }

    /**
    * @dev Modifier that requires minimum 5 airlines registered
    */
    modifier requireFiveOrMoreAirlines(){
        require(counterAirline > 4,"There is less that 5 airlines registered");
        _;
    }

    /**
    * @dev Modifier that ensures that funded amount is sufficient
    */
    modifier requireSufficientFund(){
        require(msg.value >= regFee, "Insufficient funds is sent");
        _;

    }
    /**
    * @dev Modifier that ensures the insurance amount do not exceed the predefined value of `maxInsuranceFee`
    */
    modifier requireMaxEther(){
        require(msg.value <= maxInsuranceFee,"Exceed the maximum allowed amount for an insurance");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns(bool)
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus (bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    */   

    function registerAirline(address _address) external requireRegisteredAirline returns(uint256){
        bool success = false;

        if(counterAirline < 5){
            success = registerFourOrLessAirlines(_address);
            counterAirline++;
        }else{
            if(airlines[_address].isRegistered != true || airlines[_address].isRegistered != false){
                counterAirline++;
            }
            success = registerFiveOrMoreAirlines(_address);
        }

        require(success,"Airline didn't register");

        return counterAirline;
    }

    /*
    *   @dev Add the very first airline to the registration queue
    *    It is called from the constructor only
    */
    function registerTheFirstAirline(address _address) internal requireContractOwner {
        airlines[_address].votes.push(msg.sender);
        airlines[_address].isRegistered = true;

        counterAirline++;
    }

    /*
     *   @dev Registers airlines by existing airlines
     */
    function registerFourOrLessAirlines(address _address) internal requireFourOrLessAirlines returns(bool){
        airlines[_address].votes.push(msg.sender);
        airlines[_address].isRegistered = true;

        return airlines[_address].isRegistered;
    }

    /*
    *   @dev Registers airlines with Consensus after having 5 or more airlines already registered
    */
    function registerFiveOrMoreAirlines(address _address) internal requireFiveOrMoreAirlines returns (bool) {
        airlines[_address].votes.push(msg.sender);

        uint256 votes = airlines[_address].votes.length;
        uint256 halfRegistered = counterAirline.div(2);
        if( votes > halfRegistered ) {
            airlines[_address].isRegistered = true;
        }else{
            airlines[_address].isRegistered = false;
        }

        return airlines[_address].isRegistered;
    }

    /**
    * @dev Checks if the airline is registered or not
    */
    function isAirline(address _address) external view returns(bool){

        return airlines[_address].isRegistered;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(string _flightNo) external payable requireMaxEther returns(uint256){

        insurances[msg.sender].paidAmount = msg.value;
        insurances[msg.sender].flightNo = _flightNo;

        return insurances[msg.sender].balance;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address _address) external returns(uint256, uint256){

        uint256 credit = insurances[_address].paidAmount;
        credit += credit.div(2);
        insurances[_address].balance += credit;

        return (credit, insurances[_address].balance);

    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay() external payable returns(uint256, uint256){
        uint256 credit = insurances[msg.sender].balance;
        insurances[msg.sender].balance = 0;
        msg.sender.transfer(credit);

        return(credit, insurances[msg.sender].balance);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund() public payable requireSufficientFund returns(uint256) {

        uint256 theBalance =  address(this).balance;
        airlines[msg.sender].isFunded = true;
        return theBalance;

    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        fund();
    }


}

