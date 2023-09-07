// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether; //1e17
    uint256 constant STARTING_BAL = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BAL); // vm.deal set the balance of an address to newBalance
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        console.log(fundMe.getOwner());
        // console.log(address(this));
        console.log(msg.sender);
        assertEq(fundMe.getOwner(), msg.sender);
    }

    // getVersion address don't exist. Testing multiple contract
    function testPriceFeedVersionIsAccurate() public {
        // console.log(fundMe.getVersion());
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundMeFailsWithoutEnoughETH() public {
        vm.expectRevert();
        fundMe.fund{value: 1e10}();
    }

    function testFundUpdateFundedDataStructure() public {
        vm.prank(USER); // The next Tx will be sent by USER. //forge cheatcode use vm.
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddresstoToAmountFunded(USER); //address of FundMe, contract address(this)
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address newFunder = fundMe.getFunders(0);
        assertEq(newFunder, USER);
    }

    modifier funded() {
        //organize unit tests by using a state tree
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert(); // next line should revert, ignore vm.
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        //Arrage
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        //Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawWithMultipleFunders() public funded {
        //        Arrage
        uint160 numberOfFunder = 10; //as of v0,8, address needs to cast address to uint256. uint160 has same amount of bits as an address
        uint160 startingFunderIndex = 1; // use uint160 if we are using numbers to create addresses/ starting index should start with 1. EVM doesn't like 0

        for (uint160 i = startingFunderIndex; i < numberOfFunder; i++) {
            //vm.prank new address
            //vm.deal new value
            // address()
            hoax(address(i), SEND_VALUE); //set up prank + deal. Forge standard lib not need for vm.
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        //Act
        uint256 gasStart = gasleft(); //gas limit - gas used. EVM code
        vm.txGasPrice(GAS_PRICE); //simulate gasPrice of 1
        vm.prank(fundMe.getOwner());
        fundMe.withdraw(); //Anvil default gas price to 0
        // vm.stopPrank();
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; //tx.gasprice is Solidity current gasprice
        console.log(gasUsed);
        console.log(tx.gasprice);
        //assert
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
        // console.log(startingFundMeBalance);
        // console.log(startingOwnerBalance);
        // console.log(fundMe.getOwner().balance);
    }

    function testCheaperWithdrawWithMultipleFunders() public funded {
        //        Arrage
        uint160 numberOfFunder = 10; //as of v0,8, address needs to cast address to uint256. uint160 has same amount of bits as an address
        uint160 startingFunderIndex = 1; // use uint160 if we are using numbers to create addresses/ starting index should start with 1. EVM doesn't like 0

        for (uint160 i = startingFunderIndex; i < numberOfFunder; i++) {
            //vm.prank new address
            //vm.deal new value
            // address()
            hoax(address(i), SEND_VALUE); //set up prank + deal. Forge standard lib not need for vm.
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        //Act
        uint256 gasStart = gasleft(); //gas limit - gas used. EVM code
        vm.txGasPrice(GAS_PRICE); //simulate gasPrice of 1
        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw(); //Anvil default gas price to 0
        // vm.stopPrank();
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice; //tx.gasprice is Solidity current gasprice
        console.log(gasUsed);
        console.log(tx.gasprice);
        //assert
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }
}
