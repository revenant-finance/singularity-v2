pragma solidity ^0.8.10;

interface ISingularityCallee {
    function SingularityCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}