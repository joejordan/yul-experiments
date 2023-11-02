// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Used in the `name()` function
// "Yul Token"
bytes32 constant nameLength = 0x0000000000000000000000000000000000000000000000000000000000000009;
bytes32 constant nameData = 0x59756c20546f6b656e0000000000000000000000000000000000000000000000;

// Used in the `symbol()` function
// "YUL"
bytes32 constant symbolLength = 0x0000000000000000000000000000000000000000000000000000000000000003;
bytes32 constant symbolData = 0x59554c0000000000000000000000000000000000000000000000000000000000;

// `bytes4(keccak256("InsufficientBalance()"))`
bytes32 constant insufficientBalanceSelector = 0xf4d678b800000000000000000000000000000000000000000000000000000000;

// `bytes4(keccak256("InsufficientAllowance(address,address)"))`
bytes32 constant insufficientAllowanceSelector = 0xf180d8f900000000000000000000000000000000000000000000000000000000;

error InsufficientBalance();
error InsufficientAllowance(address owner, address spender);

// cast keccak "Transfer(address,address,uint256)"
bytes32 constant transferHash = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
// cast keccak "Approval(address,address,uint256)"
bytes32 constant approvalHash = 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;
// max = type(uint256).max
bytes32 constant maxUint256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

/// @title Yul ERC20
/// @author JOEMAN
/// @notice For learning purposes only
contract YulERC20 {
    event Transfer(address indexed sender, address indexed receiver, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    // owner -> balance
    mapping(address => uint256) internal _balances;
    // owner -> spender -> allowance
    // Assembly:
    // keccak256(spender, keccak256(owner, slot))
    mapping(address => mapping(address => uint256)) internal _allowances;

    uint256 internal _totalSupply;

    constructor() {
        assembly {
            // store into the caller balance the initial supply
            mstore(0x00, caller()) // store the caller address
            mstore(0x20, 0x00) // store the balances slot (which is zer0)

            // hash the address + balances slot
            let slot := keccak256(0x00, 0x40)
            sstore(slot, maxUint256)  // the total supply is the max uint256

            // increase the total supply
            sstore(0x02, maxUint256)

            // log the transfer
            mstore(0x00, maxUint256)
            // log3(memoryPointer, memorySize, transfer eventHash, sender, receiver)
            log3(0x00, 0x20, transferHash, 0x00, caller())
        }
    }

    function name() public pure returns (string memory) {
        assembly {
            let memptr := mload(0x40)
            mstore(memptr, 0x20)
            mstore(add(memptr, 0x20), nameLength)
            mstore(add(memptr, 0x40), nameData)
            return(memptr, 0x60)
        }
    }

    function symbol() public pure returns (string memory) {
        assembly {
            let memptr := mload(0x40)
            // store the string pointer
            mstore(memptr, 0x20)
            // store the length
            mstore(add(memptr, 0x20), symbolLength)
            // store data
            mstore(add(memptr, 0x40), symbolData)
            return(memptr, 0x60)
        }
    }

    function decimals() public pure returns (uint8) {
        assembly {
            mstore(0, 18)
            return(0x00, 0x20)
        }
    }

    function totalSupply() public view returns (uint256) {
        assembly {
            mstore(0x00, sload(0x02)) // load _totalSupply as found in slot 2
            return(0x00, 0x20)
        }
    }

    function balanceOf(address) public view returns (uint256) {
        assembly {
            // VERBOSE VERSION:
            // let account := calldataload(4)
            // mstore(0x00, account)
            // mstore(0x20, 0x00)
            // // hash address + slot
            // let hash := keccak256(0x00, 0x40)
            // let accountBalance := sload(hash)

            // mstore(0x00, accountBalance)
            // return(0x00, 0x20)
            
            // PRODUCTION VERSION:
            // calldataload(4) is the account address the function is called with
            mstore(0x00, calldataload(4))
            // store slot to hash with
            mstore(0x20, 0x00)
            // keccak => pointer, memory amount
            // account balance => sload(keccak256(0x00, 0x40))
            mstore(0x00, sload(keccak256(0x00, 0x40)))
            return(0x00, 0x20)
        }
    }

    function transfer(address receiver, uint256 value) public returns (bool) {
        assembly {
            // get free mem pointer
            let memptr := mload(0x40)

            // load caller balance, assert sufficient
            mstore(memptr, caller())
            // store the balance slot (which is zer0)
            mstore(add(memptr, 0x20), 0x00)
            let callerBalanceSlot := keccak256(memptr, 0x40)
            let callerBalance := sload(callerBalanceSlot)

            if lt(callerBalance, value) {
                // revert
                mstore(0x00, insufficientBalanceSelector)
                // revert with selector
                revert(0x00, 0x04)
            }

            if eq(caller(), receiver) {
                // cannot send tokens to self
                revert(0x00, 0x00)
            }

            // decrease caller balance
            let newCallerBalance := sub(callerBalance, value)
            sstore(callerBalanceSlot, newCallerBalance)

            // load receiver balance
            mstore(memptr, receiver)
            mstore(add(memptr, 0x20), 0x00)

            let receiverBalanceSlot := keccak256(memptr, 0x40)
            let receiverBalance := sload(receiverBalanceSlot)

            // increase receiver balance
            let newReceiverBalance := add(receiverBalance, value)

            // store back into storage
            sstore(callerBalanceSlot, newCallerBalance)
            sstore(receiverBalanceSlot, newReceiverBalance)

            // store `value` on stack, log
            mstore(0x00, value)
            log3(0x00, 0x20, transferHash, caller(), receiver)


            // return to the caller a boolean success result
            mstore(0x00, 0x01)
            return(0x00, 0x20)
        }
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        assembly {
            mstore(0x00, owner)  // mem store owner 
            mstore(0x20, 0x01)  //  mem store slot number of _allowances mapping
            let innerHash := keccak256(0x00, 0x40) // hash owner + slot

            mstore(0x00, spender)
            mstore(0x20, innerHash)
            let allowanceSlot := keccak256(0x00, 0x40)

            let allowanceValue := sload(allowanceSlot)
            mstore(0x00, allowanceValue)
            return(0x00, 0x20)
        }
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        assembly {
            mstore(0x00, caller())                  // store msg.sender
            mstore(0x20, 0x01)                      // store slot number of _allowances mapping
            let innerHash := keccak256(0x00, 0x40)  // hash msg.sender + slot

            mstore(0x00, spender)
            mstore(0x20, innerHash)
            let allowanceSlot := keccak256(0x00, 0x40)

            sstore(allowanceSlot, amount)

            mstore(0x00, amount)
            log3(0x00, 0x20, approvalHash, caller(), spender)

            mstore(0x00, 0x01)  // store bool for true
            return(0x00, 0x20)  // return bool
        }
    }

    function transferFrom(address sender, address receiver, uint256 amount) public returns (bool) {
        assembly {
            let memptr := mload(0x40)

            // generate allowance slot
            mstore(0x00, sender)
            mstore(0x20, 0x01)
            let innerHash := keccak256(0x00, 0x40)

            mstore(0x00, caller())
            mstore(0x20, innerHash)
            let allowanceSlot := keccak256(0x00, 0x40)

            let callerAllowance := sload(allowanceSlot)

            // check for sufficient allowance
            if lt(callerAllowance, amount) {
                mstore(memptr, insufficientAllowanceSelector)
                mstore(add(memptr, 0x04), sender)
                mstore(add(memptr, 0x24), caller())
                revert(memptr, 0x44)
            }

            // decrease allowance
            if lt(callerAllowance, maxUint256) {
                sstore(allowanceSlot, sub(callerAllowance, amount))
            }

            // load sender balance
            mstore(memptr, sender)
            mstore(add(memptr, 0x20), 0x00)
            let senderBalanceSlot := keccak256(memptr, 0x40)
            let senderBalance := sload(senderBalanceSlot)

            // check for sufficient balance
            if lt(senderBalance, amount) {
                mstore(memptr, insufficientBalanceSelector)
                revert(memptr, 0x04)
            }

            // decrease sender balance
            sstore(senderBalanceSlot, sub(senderBalance, amount))

            // load receiver balance
            mstore(memptr, receiver)
            mstore(add(memptr, 0x20), 0x00)
            let receiverBalanceSlot := keccak256(memptr, 0x40)
            let receiverBalance := sload(receiverBalanceSlot)

            // increase receiver balance
            sstore(receiverBalanceSlot, add(receiverBalance, amount))

            // log transfer
            mstore(0x00, amount)
            log3(0x00, 0x20, transferHash, sender, receiver)

            // return success (true)
            mstore(0x00, 0x01)
            return(0x00, 0x20)

        }
    }
}