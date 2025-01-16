// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GasConsumingMock {
    uint256 public counter;
    
    receive() external payable {
        // Do multiple simple operations
        counter += 1;
        counter *= 2;
        counter -= 1;
        counter |= 1;
        counter &= type(uint256).max;
        counter ^= 0xFFFF;
    }
}
