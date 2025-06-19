// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Lending Protocol
 * @dev A peer-to-peer lending platform where users can deposit collateral and borrow tokens
 * @author Your Name
 */
contract Project {
    // State variables
    mapping(address => uint256) public collateralBalances;
    mapping(address => uint256) public borrowedAmounts;
    mapping(address => uint256) public lastBorrowTime;
    
    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization required
    uint256 public constant INTEREST_RATE = 5; // 5% annual interest rate
    uint256 public constant SECONDS_IN_YEAR = 365 * 24 * 60 * 60;
    
    uint256 public totalCollateral;
    uint256 public totalBorrowed;
    
    // Events
    event CollateralDeposited(address indexed user, uint256 amount);
    event TokensBorrowed(address indexed user, uint256 amount);
    event LoanRepaid(address indexed user, uint256 amount, uint256 interest);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event CollateralLiquidated(address indexed user, uint256 collateralAmount, uint256 debtAmount);
    
    // Modifiers
    modifier hasCollateral(address user) {
        require(collateralBalances[user] > 0, "No collateral deposited");
        _;
    }
    
    modifier hasBorrowedTokens(address user) {
        require(borrowedAmounts[user] > 0, "No active loan");
        _;
    }
    
    /**
     * @dev Deposit ETH as collateral to enable borrowing
     * Users must deposit collateral before they can borrow tokens
     */
    function depositCollateral() external payable {
        require(msg.value > 0, "Must deposit some ETH as collateral");
        
        collateralBalances[msg.sender] += msg.value;
        totalCollateral += msg.value;
        
        emit CollateralDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Borrow tokens against deposited collateral
     * @param amount The amount of tokens to borrow (in wei)
     * Requires 150% collateralization ratio
     */
    function borrowTokens(uint256 amount) external hasCollateral(msg.sender) {
        require(amount > 0, "Borrow amount must be greater than 0");
        
        // Calculate maximum borrowable amount based on collateral
        uint256 maxBorrowable = (collateralBalances[msg.sender] * 100) / COLLATERAL_RATIO;
        uint256 currentDebt = calculateTotalDebt(msg.sender);
        
        require(currentDebt + amount <= maxBorrowable, "Insufficient collateral for requested loan amount");
        require(address(this).balance >= amount, "Insufficient liquidity in protocol");
        
        // Update borrowing records
        borrowedAmounts[msg.sender] += amount;
        lastBorrowTime[msg.sender] = block.timestamp;
        totalBorrowed += amount;
        
        // Transfer tokens to borrower
        payable(msg.sender).transfer(amount);
        
        emit TokensBorrowed(msg.sender, amount);
    }
    
    /**
     * @dev Repay borrowed tokens with interest
     * Users can make partial or full repayments
     */
    function repayLoan() external payable hasBorrowedTokens(msg.sender) {
        require(msg.value > 0, "Repayment amount must be greater than 0");
        
        uint256 totalDebt = calculateTotalDebt(msg.sender);
        require(msg.value <= totalDebt, "Repayment exceeds total debt");
        
        uint256 principal = borrowedAmounts[msg.sender];
        uint256 interest = totalDebt - principal;
        
        if (msg.value >= totalDebt) {
            // Full repayment
            borrowedAmounts[msg.sender] = 0;
            totalBorrowed -= principal;
            
            // Return excess payment if any
            if (msg.value > totalDebt) {
                payable(msg.sender).transfer(msg.value - totalDebt);
            }
            
            emit LoanRepaid(msg.sender, principal, interest);
        } else {
            // Partial repayment - reduce principal proportionally
            uint256 principalReduction = (msg.value * principal) / totalDebt;
            borrowedAmounts[msg.sender] -= principalReduction;
            totalBorrowed -= principalReduction;
            lastBorrowTime[msg.sender] = block.timestamp; // Reset interest calculation
            
            emit LoanRepaid(msg.sender, principalReduction, msg.value - principalReduction);
        }
    }
    
    /**
     * @dev Withdraw collateral (only if no outstanding debt or sufficient collateral remains)
     * @param amount Amount of collateral to withdraw
     */
    function withdrawCollateral(uint256 amount) external hasCollateral(msg.sender) {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(amount <= collateralBalances[msg.sender], "Insufficient collateral balance");
        
        uint256 totalDebt = calculateTotalDebt(msg.sender);
        uint256 remainingCollateral = collateralBalances[msg.sender] - amount;
        
        if (totalDebt > 0) {
            uint256 requiredCollateral = (totalDebt * COLLATERAL_RATIO) / 100;
            require(remainingCollateral >= requiredCollateral, "Withdrawal would violate collateral ratio");
        }
        
        collateralBalances[msg.sender] -= amount;
        totalCollateral -= amount;
        
        payable(msg.sender).transfer(amount);
        
        emit CollateralWithdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Liquidate undercollateralized positions
     * @param user Address of the user to liquidate
     * Anyone can call this function to liquidate undercollateralized positions
     */
    function liquidate(address user) external {
        require(borrowedAmounts[user] > 0, "User has no active loan");
        
        uint256 totalDebt = calculateTotalDebt(user);
        uint256 collateral = collateralBalances[user];
        uint256 requiredCollateral = (totalDebt * COLLATERAL_RATIO) / 100;
        
        require(collateral < requiredCollateral, "Position is not undercollateralized");
        
        // Liquidate the position
        borrowedAmounts[user] = 0;
        collateralBalances[user] = 0;
        totalBorrowed -= (totalDebt - (totalDebt - borrowedAmounts[user])); // Adjust for principal only
        totalCollateral -= collateral;
        
        // Transfer collateral to liquidator (could implement liquidation bonus)
        payable(msg.sender).transfer(collateral);
        
        emit CollateralLiquidated(user, collateral, totalDebt);
    }
    
    /**
     * @dev Calculate total debt including accrued interest
     * @param user Address of the borrower
     * @return Total debt amount including interest
     */
    function calculateTotalDebt(address user) public view returns (uint256) {
        if (borrowedAmounts[user] == 0) {
            return 0;
        }
        
        uint256 principal = borrowedAmounts[user];
        uint256 timeElapsed = block.timestamp - lastBorrowTime[user];
        uint256 interest = (principal * INTEREST_RATE * timeElapsed) / (100 * SECONDS_IN_YEAR);
        
        return principal + interest;
    }
    
    /**
     * @dev Get user's borrowing capacity
     * @param user Address of the user
     * @return Maximum amount the user can borrow
     */
    function getBorrowingCapacity(address user) external view returns (uint256) {
        if (collateralBalances[user] == 0) {
            return 0;
        }
        
        uint256 maxBorrowable = (collateralBalances[user] * 100) / COLLATERAL_RATIO;
        uint256 currentDebt = calculateTotalDebt(user);
        
        return maxBorrowable > currentDebt ? maxBorrowable - currentDebt : 0;
    }
    
    /**
     * @dev Get protocol statistics
     * @return totalCollateral Total collateral in the protocol
     * @return totalBorrowed Total amount borrowed
     * @return utilizationRate Current utilization rate as percentage
     */
    function getProtocolStats() external view returns (uint256, uint256, uint256) {
        uint256 utilizationRate = totalCollateral > 0 ? (totalBorrowed * 100) / totalCollateral : 0;
        return (totalCollateral, totalBorrowed, utilizationRate);
    }
    
    /**
     * @dev Check if a position is liquidatable
     * @param user Address to check
     * @return true if position can be liquidated
     */
    function isLiquidatable(address user) external view returns (bool) {
        if (borrowedAmounts[user] == 0) {
            return false;
        }
        
        uint256 totalDebt = calculateTotalDebt(user);
        uint256 collateral = collateralBalances[user];
        uint256 requiredCollateral = (totalDebt * COLLATERAL_RATIO) / 100;
        
        return collateral < requiredCollateral;
    }
    
    // Allow contract to receive ETH
    receive() external payable {
        // This allows the contract to receive ETH for liquidity
    }
    
    // Fallback function
    fallback() external payable {
        revert("Function not found");
    }
}
