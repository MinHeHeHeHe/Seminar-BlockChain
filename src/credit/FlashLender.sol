// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Flash Loan implementation (Aave-like)
// Cho phép borrow token trong 1 transaction với phí nhỏ

import "../interfaces/CommonInterfaces.sol";

interface IFlashBorrower {
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

contract FlashLender {
    uint256 public constant FEE_RATE = 9; // 0.09% fee (9/10000)
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    
    mapping(address => bool) public supportedTokens;
    address[] public tokenList;
    
    event FlashLoan(address indexed borrower, address indexed token, uint256 amount, uint256 fee);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);

    constructor(address[] memory _tokens) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            supportedTokens[_tokens[i]] = true;
            tokenList.push(_tokens[i]);
            emit TokenAdded(_tokens[i]);
        }
    }

    function addToken(address token) external {
        require(!supportedTokens[token], "Already supported");
        supportedTokens[token] = true;
        tokenList.push(token);
        emit TokenAdded(token);
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        if (!supportedTokens[token]) return 0;
        return IERC20(token).balanceOf(address(this));
    }

    function flashFee(address token, uint256 amount) public pure returns (uint256) {
        require(token != address(0), "Invalid token");
        return (amount * FEE_RATE) / FEE_DENOMINATOR;
    }

    function flashLoan(
        IFlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        require(supportedTokens[token], "Token not supported");
        
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "Insufficient liquidity");
        
        uint256 fee = flashFee(token, amount);
        
        // Transfer tokens to borrower
        require(IERC20(token).transfer(address(receiver), amount), "Transfer failed");
        
        // Call borrower's callback
        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,
            "Callback failed"
        );
        
        // Check repayment
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flash loan not repaid");
        
        emit FlashLoan(msg.sender, token, amount, fee);
        return true;
    }

    function getTokenList() external view returns (address[] memory) {
        return tokenList;
    }

    // Allow deposits for liquidity
    function deposit(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    // Withdraw (for demonstration purposes, in production should have access control)
    function withdraw(address token, uint256 amount) external {
        IERC20(token).transfer(msg.sender, amount);
    }
}

// Helper contract for testing flash loans
contract FlashBorrowerMock is IFlashBorrower {
    address public lender;
    
    event FlashLoanReceived(address token, uint256 amount, uint256 fee);

    constructor(address _lender) {
        lender = _lender;
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == lender, "Untrusted lender");
        require(initiator == address(this), "Untrusted initiator");
        
        emit FlashLoanReceived(token, amount, fee);
        
        // Do something with the borrowed tokens
        // (custom logic would go here)
        
        // Approve repayment
        IERC20(token).approve(lender, amount + fee);
        
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function executeFlashLoan(address token, uint256 amount) external {
        FlashLender(lender).flashLoan(this, token, amount, "");
    }
}

