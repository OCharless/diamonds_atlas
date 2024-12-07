// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibERC20 {
    struct ERC20DiamondStorage {
        bool initialized;
        // Token name
        string _name;
        // Token symbol
        string _symbol;
        // Number of minted tokens
        uint256 _totalSupply;
        // Decimals
        uint8 _decimals;
        //Hero's address
        address _heroAddress;
        // Mapping owner address to token count
        mapping(address => uint256) _balances;
        // Mapping from owner to operator approvals
        mapping(address => mapping(address => bool)) _operatorApprovals;
    }

    // Declare the Transfer event
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Returns the struct from a specified position in contract storage
    // ds is short for DiamondStorage
    function diamondStorage() internal pure returns (ERC20DiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.erc20.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        ERC20DiamondStorage storage ds = diamondStorage();

        ds._totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            ds._balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        ERC20DiamondStorage storage ds = diamondStorage();

        uint256 accountBalance = ds._balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            ds._balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            ds._totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }

    function _balanceOf(address owner) internal view returns (uint256) {
        ERC20DiamondStorage storage ds = diamondStorage();
        return ds._balances[owner];
    }
}
