// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {
    uint256 constant LOCK_TIME = 2 days;
    uint256 constant REWARD_INTERVAL = 1 days;
    uint256 constant ROI_PERIOD = 365;
    address public tokenAddress;
    address public poolAddress;
    address public feeAddress;
    mapping(address => uint256[]) amounts;
    mapping(address => uint256[]) times;
    mapping(address => uint256[]) harvests;

    constructor(
        address tokenAddr,
        address poolAddr,
        address feeAddr
    ) {
        tokenAddress = tokenAddr;
        poolAddress = poolAddr;
        feeAddress = feeAddr;
    }

    function stake(uint256 amount) external {
        require(
            IERC20(tokenAddress).balanceOf(msg.sender) >= amount,
            "Insufficient Fund"
        );
        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount - amount / 20
        );
        IERC20(tokenAddress).transferFrom(msg.sender, feeAddress, amount / 20);
        amounts[msg.sender].push(amount);
        times[msg.sender].push(block.timestamp);
        harvests[msg.sender].push(0);
    }

    function claimable(address user) public view returns (uint256) {
        uint256 length = amounts[user].length;
        uint256 claimableAmount;
        for (uint256 i = 0; i < length; ++i) {
            claimableAmount += claimableAt(user, times[user][i]);
        }
        return claimableAmount;
    }

    function claimableAt(address user, uint256 timestamp)
        public
        view
        returns (uint256)
    {
        uint256 length = amounts[user].length;
        uint256 i;
        for (i = 0; i < length && times[user][i] != timestamp; ++i) {}
        require(i < length, "No Stakes like that");
        if (block.timestamp - times[user][i] < LOCK_TIME) {
            return 0;
        }
        return
            (amounts[user][i] *
                3 *
                ((block.timestamp - times[user][i]) / REWARD_INTERVAL)) /
            ROI_PERIOD -
            harvests[user][i];
    }

    function harvest() external {
        uint256 claimableAmount = claimable(msg.sender);
        require(claimableAmount > 0, "No Claimable Token");
        require(
            IERC20(tokenAddress).balanceOf(poolAddress) >= claimableAmount,
            "Insufficient Fund in Pool"
        );
        IERC20(tokenAddress).transferFrom(
            poolAddress,
            msg.sender,
            claimableAmount
        );
        uint256 length = amounts[msg.sender].length;
        for (uint256 i = 0; i < length; ++i) {
            if (block.timestamp - times[msg.sender][i] >= LOCK_TIME) {
                harvests[msg.sender][i] =
                    (amounts[msg.sender][i] *
                        3 *
                        ((block.timestamp - times[msg.sender][i]) /
                            REWARD_INTERVAL)) /
                    ROI_PERIOD;
            }
        }
    }

    function harvestAt(uint256 timestamp) external {
        uint256 claimableAmount = claimableAt(msg.sender, timestamp);
        require(claimableAmount > 0, "No Claimable Token");
        uint256 length = amounts[msg.sender].length;
        uint256 i;
        for (i = 0; i < length && times[msg.sender][i] != timestamp; ++i) {}
        require(i < length, "No Stakes like that");
        require(
            IERC20(tokenAddress).balanceOf(poolAddress) >= claimableAmount,
            "Insufficient Fund in Pool"
        );
        IERC20(tokenAddress).transferFrom(
            poolAddress,
            msg.sender,
            claimableAmount
        );
        harvests[msg.sender][i] =
            (amounts[msg.sender][i] *
                3 *
                ((block.timestamp - times[msg.sender][i]) / REWARD_INTERVAL)) /
            ROI_PERIOD;
    }

    function unstake(uint256 timestamp, uint256 amount) external {
        uint256 length = amounts[msg.sender].length;
        uint256 i;
        for (i = 0; i < length && times[msg.sender][i] != timestamp; ++i) {}
        require(i < length, "No Stakes like that");
        require(
            block.timestamp - times[msg.sender][i] >= LOCK_TIME,
            "Lock Period"
        );
        require(amounts[msg.sender][i] >= amount, "Insufficient staked token");
        uint256 claimableAmount = claimableAt(msg.sender, timestamp);
        require(
            IERC20(tokenAddress).balanceOf(poolAddress) >= claimableAmount,
            "Insufficient Fund in Pool"
        );
        IERC20(tokenAddress).transferFrom(
            poolAddress,
            msg.sender,
            claimableAmount
        );
        IERC20(tokenAddress).transfer(feeAddress, amount / 20);
        IERC20(tokenAddress).transfer(msg.sender, amount - (amount / 20) * 2);
        if (amounts[msg.sender][i] == amount) {
            amounts[msg.sender][i] = amounts[msg.sender][length - 1];
            amounts[msg.sender].pop();
            times[msg.sender][i] = times[msg.sender][length - 1];
            times[msg.sender].pop();
            harvests[msg.sender][i] = harvests[msg.sender][length - 1];
            harvests[msg.sender].pop();
        } else {
            amounts[msg.sender][i] -= amount;
            times[msg.sender][i] = block.timestamp;
            harvests[msg.sender][i] = 0;
        }
    }

    function getStakingInfo(address user)
        external
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        uint256 length = amounts[user].length;
        uint256[] memory claimables = new uint256[](length);
        uint256 i;
        for (i = 0; i < length; ++i) {
            claimables[i] = claimableAt(user, times[user][i]);
        }
        return (amounts[user], times[user], harvests[user], claimables);
    }
}
