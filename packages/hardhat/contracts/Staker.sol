// SPDX-License-Identifier: MIT
pragma solidity 0.8.4; //Do not change the solidity version as it negativly impacts submission grading

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

/**
 * @title Staker
 * @dev A contract that allows users to stake ether and execute a function on an external contract when a certain threshold is reached.
 */
contract Staker {
    ExampleExternalContract public exampleExternalContract;

    uint256 public constant THRESHOLD = 1 ether;

    uint256 public deadline = block.timestamp + 72 hours;
    mapping(address => uint256) public balances;

    bool public openForWithdraw = false;

    event Stake(address indexed staker, uint256 amount);

    error Staker__ExternalContractComplete();
    error Staker__WithdrawWindowNotOpen();
    error Staker__NothingToWithdraw(address staker, uint256 amount);
    error Staker__WithdrawFailed(address staker, uint256 amount);

    modifier notComplete() {
        if (exampleExternalContract.completed()) {
            revert Staker__ExternalContractComplete();
        }
        _;
    }

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
    }

    function stake() public payable notComplete {
        balances[msg.sender] += msg.value;
        emit Stake(msg.sender, msg.value);
    }

    function execute() public notComplete {
        if (block.timestamp >= deadline && address(this).balance >= THRESHOLD) {
            exampleExternalContract.complete{value: address(this).balance}();
        }

        if (address(this).balance < THRESHOLD) {
            // I think that users should be able to withdraw their funds if the threshold is not reached
            openForWithdraw = true;
        }
    }

    function withdraw() public notComplete {
        if (!openForWithdraw) {
            revert Staker__WithdrawWindowNotOpen();
        }
        if (balances[msg.sender] == 0) {
            revert Staker__NothingToWithdraw(msg.sender, balances[msg.sender]);
        }
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        openForWithdraw = false; // I think that the window should be closed after a successful withdrawal
        if (!success) {
            revert Staker__WithdrawFailed(msg.sender, amount);
        }
    }

    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    receive() external payable {
        stake();
    }
}
