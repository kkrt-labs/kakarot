// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

contract Safe {
    constructor() payable {}

    receive() external payable {}

    function withdrawTransfer() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawCall() external {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    function deposit() public payable {}
}
