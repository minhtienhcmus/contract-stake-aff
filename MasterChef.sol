// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/pancakeswap/pancake-swap-periphery/blob/master/contracts/interfaces/IPancakeRouter02.sol";

// Factory interface (for creating pairs, etc.)
import "https://github.com/pancakeswap/pancake-swap-core/blob/master/contracts/interfaces/IPancakeFactory.sol";

// Pair interface (for interacting with liquidity pairs)
import "https://github.com/pancakeswap/pancake-swap-core/blob/master/contracts/interfaces/IPancakePair.sol";
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function mintFromContract (address account, uint256 amount) external;
}

contract PNCToTokenMinter is Ownable(msg.sender) {
    // uint256 public constant EXCHANGE_RATE = 100; // 1 BNB = 100 XXXXXX tokens
    struct Deposit {
        uint256 amount;  // Amount of BNB deposited
        uint256 _timestamp;  // Time of deposit
    }
    IERC20 public token; // XXXXXX token contract
    mapping(address => Deposit) public minters;
    uint256 public difficute = 1;
    uint256 public pncMinterPerDay = 82191000000000000000000;
    address public foundationAdd;
    address public affAdd;
    address public ecosystemAdd;
    address public lpAddress;
    address public operationAdd;
    address public monitorAdd;
    uint256 private ecosPercent = 15; 
    uint256 private operatorPercent = 6; 
    uint256 private lpPercent = 1; 
    uint256 public totalBNB;
    uint256 public pncMinterOn1BNBPerSecond = 1740000000000000;
    bool public flag = false;
    bool public flagAuto = false;
    address public  constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    event depositBNBEvent(address add,  uint256 amount);
    event claimTokenPNC(address add,  uint256 amount,uint256 timestamp);
    IPancakeRouter02 public pancakeRouter;
    constructor(IERC20 _token, address _foundationAdd,address _affAdd, address _ecosystemAdd, address _lpAdd, address _operationAdd, address _monitorAdd) {
        token = _token;
        foundationAdd = _foundationAdd;
        affAdd = _affAdd;
        ecosystemAdd = _ecosystemAdd;
        operationAdd = _operationAdd;
        lpAddress = _lpAdd;
        monitorAdd = _monitorAdd;
        pancakeRouter = IPancakeRouter02(PANCAKE_ROUTER);
    }

    // Function to mint XXXXXX tokens when BNB is deposited
    function depositBNB() external  payable {
        require(msg.value > 0, "Must send BNB to mint tokens");
        // uint256 amountToMint = msg.value * EXCHANGE_RATE;
        totalBNB += msg.value;
        Deposit memory infoMint = minters[msg.sender];
        if(infoMint.amount > 0){
            uint256 _amount = getAmountMinter(msg.sender);
            require(_amount > 0, "Amount mint must greater than 0");
            token.mintFromContract(msg.sender, _amount);
        }
        minters[msg.sender] = Deposit({
            amount: msg.value + infoMint.amount,
            _timestamp: block.timestamp
        });

        // require(token.balanceOf(address(this)) >= amountToMint, "Insufficient tokens in contract");
        // token.transfer(msg.sender, amountToMint);
        uint256 _amountFoundation = msg.value * 20/100;
        (bool success, ) = payable(foundationAdd).call{value: _amountFoundation}("");
         require(success, "Error 400");

        uint256 _amountAffAdd = msg.value * 18/100;
        (bool _success, ) = payable(affAdd).call{value: _amountAffAdd}("");
         require(_success, "Error 401");


        uint256 _amountlpa = msg.value * ecosPercent/100;
        (bool _successlp, ) = payable(ecosystemAdd).call{value: _amountlpa}("");
        require(_successlp, "Error 403");

        uint256 _amountEco = msg.value * operatorPercent/100;
        (bool _successEco, ) = payable(operationAdd).call{value: _amountEco}("");
        require(_successEco, "Error 402");

        uint256 _amountop = msg.value * lpPercent/100;
        (bool _successlpop, ) = payable(monitorAdd).call{value: _amountop}("");
        require(_successlpop, "Error 403");

        uint256 _amountlp = msg.value * 40/100;
        // Call the internal method
        if( flagAuto == true){
            (uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountBNBMin) = calculateAmounts(address(token), _amountlp);
            uint256 deadline = block.timestamp + 5 minutes;
            token.mintFromContract(address(this), amountTokenDesired); 
            _addLiquidityWithBNB(
                address(token),
                amountTokenDesired,
                amountTokenMin,
                amountBNBMin,
                lpAddress,
                deadline,
                _amountlp
            );
        } else {
            (bool _successlpq, ) = payable(lpAddress).call{value: _amountlp}("");
            require(_successlpq, "Error 406");
        }
        emit depositBNBEvent(msg.sender, msg.value);
    }

    // Allow owner to withdraw collected BNB
    function withdrawBNB(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient BNB balance");
        payable(owner()).transfer(amount);
    }
    function _addLiquidityWithBNB(
        address _token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountBNBMin,
        address to,
        uint256 deadline,
        uint256 _amountlp
    ) internal {
        // Transfer tokens from the caller to this contract
        // IERC20(token).transferFrom(msg.sender, address(this), amountTokenDesired);
        IERC20(token).approve(PANCAKE_ROUTER, amountTokenDesired);

        // Call the PancakeSwap router to add liquidity
        pancakeRouter.addLiquidityETH{value: _amountlp}(
            _token,
            amountTokenDesired,
            amountTokenMin,
            amountBNBMin,
            to,
            deadline
        );
    }
    function calculateAmounts(
        address _token,
        uint256 amountBNB
    ) public view returns (uint256 amountToken, uint256 amountTokenMin, uint256 amountBNBMin) {
        // Get the reserves of the BNB/token pair
        (uint256 reserveToken, uint256 reserveBNB) = getReserves(_token);

        // Calculate amount of tokens required based on the provided BNB amount
        amountToken = pancakeRouter.quote(amountBNB, reserveBNB, reserveToken);

        // Set the minimum token and BNB amounts (e.g., slippage tolerance of 1%)
        amountTokenMin = (amountToken * 99) / 100;
        amountBNBMin = (amountBNB * 99) / 100;

        return (amountToken, amountTokenMin, amountBNBMin);
    }
    function getReserves(address _token) public view returns (uint256 reserveToken, uint256 reserveBNB) {
        address pair = IPancakeFactory(pancakeRouter.factory()).getPair(_token, pancakeRouter.WETH());
        require(pair != address(0), "Pair not found");
        
        (uint112 reserve0, uint112 reserve1,) = IPancakePair(pair).getReserves();

        // Check the order of reserves
        (reserveToken, reserveBNB) = IPancakePair(pair).token0() == _token ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    function claimTokenMint() external  {
        uint256 _amount = getAmountMinter(msg.sender);
        Deposit memory infoMint = minters[msg.sender];
        minters[msg.sender] = Deposit({
        amount: infoMint.amount,
        _timestamp: block.timestamp
        });
        require(_amount > 0, "Amount mint must greater than 0");
        token.mintFromContract(msg.sender, _amount);
        emit claimTokenPNC(msg.sender, _amount,block.timestamp);
    }
    function setPNCMinterPerDay(uint256 _value) external onlyOwner {
        pncMinterPerDay = _value;
    }

    function setDifficute(uint256 _value) external onlyOwner {
        difficute = _value;
    }
    function setPncMinterOn1BNBPerSecond(uint256 _value) external onlyOwner {
        pncMinterOn1BNBPerSecond = _value;
    }
    function setFlag(bool _value) external onlyOwner {
        flag = _value;
    }
    function setFlagAuto(bool _value) external onlyOwner {
        flagAuto = _value;
    }
    function setToken(address _value) external onlyOwner {
        token = IERC20(_value);
    }
    function setAffAdd(address _value) external onlyOwner {
        affAdd = _value;
    }
    function setEcosystemAdd(address _value) external onlyOwner {
        ecosystemAdd = _value;
    }
    function setLpAddress(address _value) external onlyOwner {
        lpAddress = _value;
    }
    function setOperationAdd(address _value) external onlyOwner {
        operationAdd = _value;
    }
    function setFoundationAdd(address _value) external onlyOwner {
        foundationAdd = _value;
    }
    function setRouterPancakeV2(address _value) external onlyOwner {
        pancakeRouter = IPancakeRouter02(_value);
    }

    function setOperator(uint _value) external onlyOwner {
        operatorPercent = _value;
    }
    function setEcos(uint _value) external onlyOwner {
        ecosPercent = _value;
    }
    function setlp(uint _value) external onlyOwner {
        lpPercent = _value;
    }
    function getOperator() public  view onlyOwner returns (uint256) {
        return operatorPercent;
    }
    function getEcos() public  view onlyOwner returns (uint256) {
        return ecosPercent;
    }
    function getlp() public  view onlyOwner returns (uint256) {
        return lpPercent;
    }
    function getAmountMinter(address _sender) public  view returns (uint256) {
        Deposit memory infoMint = minters[_sender];
        uint256 detaTime = block.timestamp - infoMint._timestamp;
        if(totalBNB == 0){
            return 0;
        }
        uint256 _amountMint = 0;
        if(flag == false){
         _amountMint = (infoMint.amount * detaTime * pncMinterOn1BNBPerSecond)/(10**18);
        }else {
         _amountMint = (infoMint.amount *  pncMinterPerDay * detaTime) / (totalBNB * 24 * 3600 * difficute);
        }

        return _amountMint;
    }
    // Allow owner to withdraw remaining XXXXXX tokens
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(token.balanceOf(address(this)) >= amount, "Insufficient token balance");
        token.transfer(owner(), amount);
    }
    receive() external payable {}
    fallback() external payable {}
}
