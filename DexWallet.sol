// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

library Helper {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function symbol() external view returns (string memory);
}

contract DexWallet is Ownable, ReentrancyGuard {
    // 存储所有充值过的ERC20合约地址
    address[] public allTokens;

    // 记录所有充值过ETH的用户地址
    address[] public allETHUsers;

    // 记录所有充值过ewrc20代币的用户地址
    address[] public allERC20Users;

    // 充值代币信息
    struct DepositTokenInfo {
        // 订单号
        string orderNumber;
        // 代币简称
        string tokenSymbol;
        // 代币合约地址
        address tokenAddress;
        // 充值的人
        address sender;
        // 充值金额
        uint256 amount;
        // 充值的时间
        uint256 timestamp;
        // 充值的区块高度
        uint256 blockNumber;
    }

    // 充值ETH信息
    struct DepositETHInfo {
        // 充值的订单号
        string orderNumber;
        // 代币简称
        string tokenSymbol;
        // 代币合约地址
        address tokenAddress;
        // 充值的人
        address sender;
        // 充值金额
        uint256 amount;
        // 充值的时间
        uint256 timestamp;
        // 充值的区块高度
        uint256 blockNumber;
    }

    // 提现代币信息
    struct WithdrawTokenInfo {
        // 提币的订单号
        string orderNumber;
        // 代币简称
        string tokenSymbol;
        // 代币合约地址
        address tokenAddress;
        // 接收的人
        address receiver;
        // 提取金额
        uint256 amount;
        // 提取的时间
        uint256 timestamp;
        // 提现的区块高度
        uint256 blockNumber;
    }

    // 提现代币信息
    struct WithdrawETHInfo {
        // 提币的订单号
        string orderNumber;
        // 代币简称
        string tokenSymbol;
        // 代币合约地址
        address tokenAddress;
        // 接收的人
        address receiver;
        // 提取金额
        uint256 amount;
        // 提取的时间
        uint256 timestamp;
        // 提现的区块高度
        uint256 blockNumber;
    }

    // 记录用户充值的代币合约地址是否存在
    mapping(address => bool) private isTokenExist;
    mapping(address => bool) private isETHUserExist;
    mapping(address => bool) private isERC20UserExist;
    mapping(address => DepositETHInfo[]) public depositETHInfo;
    mapping(address => DepositTokenInfo[]) public depositTokenInfo;
    mapping(address => WithdrawETHInfo[]) public withdrawETHInfo;
    mapping(address => WithdrawTokenInfo[]) public withdrawTokenInfo;
    mapping(address => mapping(address => uint256)) public depositETHBalance;
    mapping(address => mapping(address => uint256)) public depositTokenBalance;

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Only EOA");
        _;
    }

    event Deposit(
        string orderNumber,
        address indexed tokenAddress,
        address indexed sender,
        uint256 indexed amount,
        uint256 blockNumber,
        uint256 timestamp
    );
    event Withdraw(
        string orderNumber,
        address indexed tokenAddress,
        address indexed receiver,
        uint256 indexed amount,
        uint256 blockNumber,
        uint256 timestamp
    );
    event DepositETHBalance(
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed amount,
        uint256 blockNumber,
        uint256 timestamp
    );
    event DepositTokenBalance(
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed amount,
        uint256 blockNumber,
        uint256 timestamp
    );
    event WithdrawETHByManager(
        address indexed to,
        address indexed tokenAddress,
        uint256 indexed amount,
        uint256 blockNumber,
        uint256 timestamp
    );

    event WithdrawTokenByManager(
        address indexed to,
        address indexed tokenAddress,
        uint256 indexed amount,
        uint256 blockNumber,
        uint256 timestamp
    );

    receive() external payable {}

    // 充值ETH
    fallback() external payable {
        address from = msg.sender;
        uint256 amount = msg.value;
        require(amount > 0, "Amount must be greater than zero");
        require(
            !Helper.isContract(from),
            "contract"
        );
        address tokenAddress = address(0);
        uint256 timestamp = block.timestamp;
        uint256 blockNumber = block.number;
        bytes memory data  = msg.data;
        require(data.length > 0 , "Invalid order");
        string memory data2 = string(data);
        depositETHBalance[from][tokenAddress] += amount;
        emit DepositETHBalance(
            from,
            tokenAddress,
            amount,
            blockNumber,
            timestamp
        );

        // 如果是第一次充值用户，则添加到allUsers数组中
        if (!isETHUserExist[from]) {
            allETHUsers.push(from);
            isETHUserExist[from] = true;
        }

        depositETHInfo[from].push(
            DepositETHInfo({
                orderNumber: data2,
                tokenSymbol: "ETH",
                tokenAddress: tokenAddress,
                sender: from,
                amount: amount,
                timestamp: timestamp,
                blockNumber: blockNumber
            })
        );
        emit Deposit(data2, tokenAddress, from, amount, blockNumber, timestamp);
    }

    constructor() Ownable(msg.sender) {}

    // 充值ERC20代币
    function depositToken(
        address tokenAddress,
        uint256 amount,
        string memory _orderNumber
    ) external onlyEOA nonReentrant {
        address from = msg.sender;
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");
        require(bytes(_orderNumber).length > 0, "Invalid order");
        uint256 blockNumber = block.number;
        uint256 timestamp = block.timestamp;
        depositTokenBalance[from][tokenAddress] += amount;
        emit DepositTokenBalance(
            from,
            tokenAddress,
            amount,
            blockNumber,
            timestamp
        );

        // 如果是第一次充值代币，则添加到allTokens数组中
        if (!isTokenExist[tokenAddress]) {
            allTokens.push(tokenAddress);
            isTokenExist[tokenAddress] = true;
        }

        if (!isERC20UserExist[from]) {
            allERC20Users.push(from);
            isERC20UserExist[from] = true;
        }

        depositTokenInfo[from].push(
            DepositTokenInfo({
                orderNumber: _orderNumber,
                tokenSymbol: IERC20(tokenAddress).symbol(),
                tokenAddress: tokenAddress,
                sender: from,
                amount: amount,
                timestamp: timestamp,
                blockNumber: blockNumber
            })
        );

        TransferHelper.safeTransferFrom(
            tokenAddress,
            from,
            address(this),
            amount
        );
        emit Deposit(_orderNumber, tokenAddress, from, amount, blockNumber, timestamp);
    }

    // 提取ETH
    function withdrawETH(
        address to,
        uint256 amount,
        string memory _orderNumber
    ) external onlyEOA nonReentrant {
        address from = msg.sender;
        require(
            to != address(0) && to != address(this),
            "Invalid receiver address"
        );
        require(
            amount > 0 && amount <= address(this).balance,
            "Amount must be greater than zero"
        );
        require(
            depositETHBalance[from][address(0)] >= amount,
            "Insufficient balance"
        );
        require(bytes(_orderNumber).length > 0, "Invalid order");
        uint256 timestamp = block.timestamp;
        uint256 blockNumber = block.number;
        depositETHBalance[from][address(0)] -= amount;


        // 如果是第一次充值用户，则添加到allUsers数组中
        if (!isETHUserExist[from]) {
            allETHUsers.push(from);
            isETHUserExist[from] = true;
        }

        withdrawETHInfo[from].push(
            WithdrawETHInfo({
                orderNumber: _orderNumber,
                tokenSymbol: "ETH",
                tokenAddress: address(0),
                receiver: to,
                amount: amount,
                timestamp: timestamp,
                blockNumber: blockNumber
            })
        );

        TransferHelper.safeTransferETH(to, amount);
        emit Withdraw( _orderNumber, address(0), to, amount, blockNumber, timestamp);
    }

    // 提取ERC20代币
    function withdrawToken(
        address tokenAddress,
        address to,
        uint256 amount,
        string memory _orderNumber
    ) external onlyEOA nonReentrant {
        address from = msg.sender;
        require(tokenAddress != address(0), "Invalid token address");
        require(
            to != address(0) && to != address(this),
            "Invalid receiver address"
        );
        require(
            amount > 0 &&
                amount <= IERC20(tokenAddress).balanceOf(address(this)),
            "Amount must be greater than zero"
        );
        require(
            depositTokenBalance[from][tokenAddress] >= amount,
            "Insufficient balance"
        );
        require(bytes(_orderNumber).length > 0, "Invalid order");
        uint256 timestamp = block.timestamp;
        uint256 blockNumber = block.number;
        depositTokenBalance[from][tokenAddress] -= amount;

        withdrawTokenInfo[from].push(
            WithdrawTokenInfo({
                orderNumber: _orderNumber,
                tokenSymbol: IERC20(tokenAddress).symbol(),
                tokenAddress: tokenAddress,
                receiver: to,
                amount: amount,
                timestamp: timestamp,
                blockNumber: blockNumber
            })
        );
        // 转账erc20代币到合约
        TransferHelper.safeTransfer(tokenAddress, to, amount);
        emit Withdraw(_orderNumber, tokenAddress, to, amount, blockNumber, timestamp);
    }

    // 获取合约内用户充值的eth，erc20代币余额
    function getETHAndERC20Balance(
        address user
    )
        external
        view
        returns (
            string memory ethSymbol,
            string[] memory tokenSymbols,
            uint256 ethBalance,
            uint256[] memory tokenBalances
        )
    {
        require(
            user != address(0) && user != address(this),
            "Invalid user address"
        );
        require(allTokens.length > 0, "No tokens in contract");
        uint256 length = allTokens.length;
        ethSymbol = "ETH";
        ethBalance = depositETHBalance[user][address(0)];
        string[] memory _tokenSymbols = new string[](length);
        uint256[] memory _tokenBalances = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            // 获取所有充值过的代币简称
            _tokenSymbols[i] = IERC20(allTokens[i]).symbol();
            // 获取用户充值的token代币币种余额
            _tokenBalances[i] = depositTokenBalance[user][allTokens[i]];
        }
        tokenSymbols = _tokenSymbols;
        tokenBalances = _tokenBalances;
    }

    // 获取合约内所有ETH, ERC20代币余额
    function getContractBalance()
        external
        view
        returns (
            string memory ethSymbol,
            string[] memory tokenSymbols,
            uint256 ethBalance,
            uint256[] memory tokenBalances
        )
    {
        uint256 length = allTokens.length;
        require(length > 0, "No tokens in contract");
        ethBalance = address(this).balance;
        ethSymbol = "ETH";

        string[] memory _tokenSymbols = new string[](length);
        uint256[] memory _tokenBalances = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            _tokenSymbols[i] = IERC20(allTokens[i]).symbol();
            _tokenBalances[i] = IERC20(allTokens[i]).balanceOf(address(this));
        }
        tokenSymbols = _tokenSymbols;
        tokenBalances = _tokenBalances;
    }

    // 根据区块高度获取用户的充值记录
    function getDepositRecordByCondition(
        address user,
        address tokenAddress,
        uint256 startBlock,
        uint256 endBlock
    )
        external
        view
        returns (
            DepositETHInfo[] memory ethInfo,
            DepositTokenInfo[] memory tokenInfo
        )
    {
        require(
            user != address(0) && user != address(this),
            "Invalid user address"
        );
        // 过滤ETH充值记录
        DepositETHInfo[] memory allEthInfo = depositETHInfo[user];
        uint256 ethCount = 0;
        for (uint256 i = 0; i < allEthInfo.length; i++) {
            if (
                (tokenAddress == address(0) ||
                    allEthInfo[i].tokenAddress == tokenAddress) &&
                allEthInfo[i].blockNumber >= startBlock &&
                allEthInfo[i].blockNumber <= endBlock
            ) {
                ethCount++;
            }
        }
        ethInfo = new DepositETHInfo[](ethCount);
        uint256 ethIndex = 0;
        for (uint256 i = 0; i < allEthInfo.length; i++) {
            if (
                (tokenAddress == address(0) ||
                    allEthInfo[i].tokenAddress == tokenAddress) &&
                allEthInfo[i].blockNumber >= startBlock &&
                allEthInfo[i].blockNumber <= endBlock
            ) {
                ethInfo[ethIndex] = allEthInfo[i];
                ethIndex++;
            }
        }

        // 过滤ERC20充值记录
        DepositTokenInfo[] memory allTokenInfo = depositTokenInfo[user];
        uint256 tokenCount = 0;
        for (uint256 i = 0; i < allTokenInfo.length; i++) {
            if (
                (tokenAddress == address(0) ||
                    allTokenInfo[i].tokenAddress == tokenAddress) &&
                allTokenInfo[i].blockNumber >= startBlock &&
                allTokenInfo[i].blockNumber <= endBlock
            ) {
                tokenCount++;
            }
        }
        tokenInfo = new DepositTokenInfo[](tokenCount);
        uint256 tokenIndex = 0;
        for (uint256 i = 0; i < allTokenInfo.length; i++) {
            if (
                (tokenAddress == address(0) ||
                    allTokenInfo[i].tokenAddress == tokenAddress) &&
                allTokenInfo[i].blockNumber >= startBlock &&
                allTokenInfo[i].blockNumber <= endBlock
            ) {
                tokenInfo[tokenIndex] = allTokenInfo[i];
                tokenIndex++;
            }
        }
    }

    // 获取用户所有的充值记录
    function getDepositRecord(
        address user
    )
        external
        view
        returns (
            DepositETHInfo[] memory ethInfo,
            DepositTokenInfo[] memory tokenInfo
        )
    {
        require(
            user != address(0) && user != address(this),
            "Invalid user address"
        );
        ethInfo = depositETHInfo[user];
        tokenInfo = depositTokenInfo[user];
    }

    // 获取用户所有的提取记录
    function getWithdrawRecord(
        address user
    )
        external
        view
        returns (
            WithdrawETHInfo[] memory ethInfo,
            WithdrawTokenInfo[] memory tokenInfo
        )
    {
        require(
            user != address(0) && user != address(this),
            "Invalid user address"
        );
        ethInfo = withdrawETHInfo[user];
        tokenInfo = withdrawTokenInfo[user];
    }

    // 管理员提取合约内ETH，ERC20代币所有余额
    function withdrawContractBalanceByManager() external onlyOwner {
        address[] memory tokenAddresses = allTokens;
        uint256 length = tokenAddresses.length;
        require(length > 0, "No tokens in contract");
        uint256 blockNumber = block.number;
        uint256 timestamp = block.timestamp;

        // 提取ETH余额
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            TransferHelper.safeTransferETH(owner(), ethBalance);
            emit WithdrawETHByManager(
                owner(),
                address(0),
                ethBalance,
                blockNumber,
                timestamp
            );
        }

        // 提取ERC20代币余额
        for (uint256 i = 0; i < length; i++) {
            address tokenAddress = tokenAddresses[i];
            uint256 tokenBalance = IERC20(tokenAddress).balanceOf(
                address(this)
            );
            if (tokenBalance > 0) {
                TransferHelper.safeTransfer(
                    tokenAddress,
                    owner(),
                    tokenBalance
                );
                emit WithdrawTokenByManager(
                    owner(),
                    tokenAddress,
                    tokenBalance,
                    blockNumber,
                    timestamp
                );
            }
        }

        // 清空所有用户的充值ETH余额
        for (uint256 i = 0; i < allETHUsers.length; i++) {
            address user = allETHUsers[i];
            depositETHBalance[user][address(0)] = 0;
        }

        // 清空所有用户的充值ERC20代币余额
        for (uint256 i = 0; i < allERC20Users.length; i++) {
            address user = allERC20Users[i];
            depositTokenBalance[user][allTokens[i]] = 0;
        }       
    }

    // 管理员提定ETH给到用户
    function withdrawUserETHBalanceByManager(address user) external onlyOwner {
        require(
            user != address(0) && user != address(this),
            "Invalid user address"
        );
        uint256 ethBalance =  depositETHBalance[user][address(0)];
        require(ethBalance > 0 && address(this).balance >= ethBalance, "User has no ETH balance");
        TransferHelper.safeTransferETH(user, ethBalance);
        emit WithdrawETHByManager(
            user,
            address(0),
            ethBalance,
            block.number,
            block.timestamp
        );
    }

    // 管理员提取ERC20代币余额给给到用户
    function withdrawUserTokenBalanceByManager(address user, address tokenAddress) external onlyOwner {
        require(
            user != address(0) && user != address(this),
            "Invalid user address"
        );
        uint256 tokenBalance = depositTokenBalance[user][tokenAddress];
        require(tokenBalance > 0 && IERC20(tokenAddress).balanceOf(address(this)) >= tokenBalance, "User has no token balance");
        TransferHelper.safeTransfer(tokenAddress, user, tokenBalance);
        emit WithdrawTokenByManager(
            user,
            tokenAddress,
            tokenBalance,
            block.number,
            block.timestamp
        );
    }



}
