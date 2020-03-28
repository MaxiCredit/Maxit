pragma solidity >=0.4.25;
import "./AddressUtils.sol";

//Last updated by Zol, 2020.03.28
contract ERC20Interface {
    function allowance(address _from, address _to) public view returns(uint);
    function transferFrom(address _from, address _to, uint _sum) public;
    function transfer(address _to, uint _sum) public;
    function balanceOf(address _owner) public view returns(uint);
}

/*
interface MXOptions {
    function mint(uint _amount) external; 
    function setOption(uint _amount, uint _lastTo) external;
}
*/
contract TestUserInterface {
    function getUserAddressCount(address _addr) public view returns(uint);
    function getUserByAddress(address _addr) public view returns(uint);
    function getUsersAddress(uint _usersId, uint _counter) public view returns(address);
}

contract MXETH {
    
    event Transfer(address indexed _from, address indexed _to, uint _sum);
    event OuterOrderCreated(address indexed _buyer, uint indexed _orderId, uint _amount);
    event OrderPaid(address indexed _buyer, uint indexed _orderId);
    event TokenBought(address indexed _buyer, uint _sum);
    event TokenBoughtFromSeller(address indexed _buyer, address _seller, uint _amount, uint indexed _offerId);
    event SetToSale(address indexed _seller, uint indexed _offerId, uint _amount, uint _unitPrice);
    event ApproveTransfer(address indexed _seller, address indexed _buyer, uint _amount);
    event TxApproval(address indexed _from, address indexed _to, uint _sum, uint _id);
    event ConvertToHederaMX(address indexed _buyer, uint indexed _amount);
    event ConvertFromHederaMX(address indexed _seller, uint indexed _amount);

    using AddressUtils for address;
    uint public initSupply;
    address public spotMarketAddress;
    address public depositAddress;
    address public futuresContractAddress; //Rename optionContarctAddress
    address public testUserAddress;
    uint supply;
    uint decimals;
    mapping(address => uint) public balanceOf;
    mapping(address => uint) public orderByAddress;
    struct OuterOrder {
       address orderAddress;
       bool orderPaid;
       uint orderAmount;
       uint orderPrice;
    }
    
    //mapping(uint => address) public orderById;
    //mapping(uint => bool) public orderPaid;
    //uint[] public orderAmountById;
    OuterOrder[] public outerOrders;
    uint public orderId = 0;
    
    mapping(address => uint) public saleOffersByAddress;
    mapping(uint => address) public saleOffersById;
    uint public saleOffersCounter = 0;
    mapping(uint => uint) public saleOffersAmount;
    mapping(uint => uint) public saleOffersUnitPrice;
    
    mapping(uint => uint) buyBackOfferByPrice;
    struct BuyBackOffer {
        uint price;
        uint amount;
    }
    BuyBackOffer[] public buyBackOffers;
    uint public buyBackOfferCounter = 0;
    uint public ETHToBuyBack = 0;
    
    mapping(address => mapping(address => uint)) public approvedTransfers;
    
    string public name;
    string public symbol;
    //address public contractOwner;
    address public operatorOfContract;
    
    address[] public serverAddress;
    uint public serverAddressArrayLength;
    mapping(address => bool) public isOurServer;
    
    uint public priceUSD; //0.01 USD cent
    uint public priceETH; 
    uint public ETHUSDprice;
    uint public lastDailyLimitUpdate;
    uint public dailyBasePrice; // 0.01 USD cent
    uint public dailyUpperBound;
    uint public dailyLowerBound;
    uint public fromWeiToEth = 10 ** 18;
    TestUserInterface tui;

    modifier onlyServer() {
        require(isOurServer[msg.sender] == true);
        _;
    }
    
    modifier operator() {
        require(msg.sender == operatorOfContract);
        _;
    }
    
   struct ToTransfer {
       address tokenFrom;
       address tokenTo;
       uint tokenAmount;
    }
    
    ToTransfer[] toTransfers;
    uint public toTransferCounter = 0;
    
    constructor (address _operator, uint _initSupply, string memory _name, string memory _symbol, uint _initPriceUSD, 
        uint _initPriceETH) public {
        operatorOfContract = _operator;        
        balanceOf[this] = _initSupply;
        initSupply = _initSupply;
        supply = initSupply;
        symbol = _symbol;
        name = _name;
        decimals = 0;
        serverAddressArrayLength = serverAddress.push(_operator);
        isOurServer[_operator] = true;
        priceUSD = _initPriceUSD;
        priceETH = _initPriceETH; //Input in wei
        ETHUSDprice = priceUSD * fromWeiToEth / priceETH;
        lastDailyLimitUpdate = now;
        dailyBasePrice = priceUSD;
        dailyUpperBound = priceUSD * 102 / 100;
        dailyLowerBound = priceUSD * 98 / 100;
    }
    
    function setDexAddress(address  _spotMarket) public operator {
        require(_spotMarket != address(0));
        spotMarketAddress = _spotMarket;
    }
    
    function setDepositAddress(address  _deposit) public operator {
        require(_deposit != address(0));
        depositAddress = _deposit;
    }
    
    function setOptionAddress(address  _futures) public operator {
        require(_futures != address(0));
        futuresContractAddress = _futures;
    }
    
    function setUserRegAddress(address  _testUser) public operator {
        require(_testUser != address(0));
        testUserAddress = _testUser;
        tui = TestUserInterface(_testUser); 
    }
            
    function totalSupply() public view returns(uint) {
        return(supply);
    }
    
    function mintByTx(uint _txAmount) private {
        //Don't add to contract's balance, but half of them to deposit, half of them to spot market
        uint supplyIncreaseHalf = uint(_txAmount / 100);
        balanceOf[address(spotMarketAddress)] += supplyIncreaseHalf;
        balanceOf[address(depositAddress)] += supplyIncreaseHalf;
        uint supplyIncrease = supplyIncreaseHalf * 2;
        supply += supplyIncrease;
    }
    
    function mintAtUpperBound(uint _txAmount) private {
        supply += _txAmount;
        balanceOf[this] += _txAmount;
        //setToSale(_txAmount, dailyUpperBound);
    }
    
    /*
    MXOptions futureCon = MXOptions(futuresContractAddress); //Rename optionCon
    function issueOptionByCredit(uint _interestRate, uint _lastTo) private {
        if(_interestRate > 2) {
            uint optionIncrease = _interestRate;
            futureCon.mint(optionIncrease); 
            futureCon.setOption(optionIncrease, _lastTo);
        }
    }
    */
    //MXoptions and MXfutures can be changed to MX from futuresAddress's balance
    //address public futuresAddress; should define in constructor
    function mintByRedeem(uint _loanAmount, uint _interestRate) private {
        if(_interestRate > 2) {
            uint supplyIncrease = uint((_loanAmount * (_interestRate - 2)) / 100);
            supply += supplyIncrease;
            //balanceOf[this] += supplyIncrease;  
            balanceOf[address(futuresContractAddress)] += supplyIncrease;
        }
    }
    
    function withdrawERC20(address _erc20Address, address _to, uint _amount) public operator {
        require(_erc20Address != address(0) && _to != address(0));
        ERC20Interface ei = ERC20Interface(_erc20Address);
        ei.transfer(_to, _amount);
    }
    
    function withdrawETH(address _to, uint _amount) public operator {
        require(_to != address(0));
        _to.transfer(_amount);
    }
    
    function setServerAddress(address _serverAddress) public operator {
        serverAddressArrayLength = serverAddress.push(_serverAddress);
        isOurServer[_serverAddress] = true;
    }
    
    function getServerAddressLength() public view returns(uint) {
        return serverAddressArrayLength;
    }
    
    function getServerAddress(uint _num) public view returns(address) {
        return serverAddress[_num];
    }
    
    function _transfer(address _from, address _to, uint _sum) private {
        require(_from != address(0));
        require(_to != address(0));
        require(_from != _to);
        require(_sum > 0);
        require(balanceOf[_from] >= _sum);
        require(balanceOf[_to] + _sum >= _sum);
        uint sumBalanceBeforeTx = balanceOf[_from] + balanceOf[_to]; 
        balanceOf[_from] -= _sum;
        balanceOf[_to] += _sum;
        assert(sumBalanceBeforeTx == balanceOf[_from] + balanceOf[_to]);
        mintByTx(_sum);
        emit Transfer(_from, _to, _sum);
    }
    
    function transfer(address _to, uint _sum) public {
        _transfer(msg.sender, _to, _sum);
    }
    
    //Using function overload
    function transfer(address _to, uint _sum, uint _interestRate, bool _isRedeem) public {
        require(_isRedeem);
        _transfer(msg.sender, _to, _sum);
        mintByRedeem(_sum, _interestRate); 
    }

    //For using other currencies like BTC, fiat...
    function createOuterOrder(uint _amount) public {
        require(_amount > 0);
        outerOrders.push(OuterOrder(msg.sender, false, _amount, priceUSD));
        orderByAddress[msg.sender] = orderId;
        emit OuterOrderCreated(msg.sender, orderId, _amount);
        orderId ++;
    }

    function outerTransfer(uint _orderId, uint _paidAmount, address _payer) public onlyServer {
        uint orderSum = outerOrders[_orderId].orderAmount * outerOrders[_orderId].orderPrice;
        require(orderSum == _paidAmount);
        require(outerOrders[_orderId].orderAddress == _payer);
        require(outerOrders[_orderId].orderPaid == false);
        outerOrders[_orderId].orderPaid = true;
        address buyerAddress = _payer;
        emit OrderPaid(buyerAddress, _orderId);
        _transfer(address(this), _payer, outerOrders[_orderId].orderAmount);
    }
    
    //Convert between blockchains
    function convertToETHMX(address _buyer, uint _amount) public onlyServer {
       _transfer(address(this), _buyer, _amount); 
       emit ConvertToHederaMX(_buyer, _amount);
    }
    
    function convertFromETHMX(uint _amount) public {
       _transfer(msg.sender, address(this), _amount);
       emit ConvertFromHederaMX(msg.sender, _amount);
    }
    
    //----------
    
    function buyToken(uint _sum) public payable {
        uint price = _sum * priceETH;
        require(msg.value == price);
        _transfer(address(this), msg.sender, _sum);
        emit TokenBought(msg.sender, _sum);
    }
    
    function getTokenBalance(address _owner) public view returns(uint) {
        return(balanceOf[_owner]);
    }
    
    function getETH(uint _amount) public payable {
        require(_amount > 0);
        require(msg.value == _amount);
        address(this).transfer(_amount);
    }
    /*
    function setToSale(uint _amount, uint _unitPrice) public {
        require(balanceOf[msg.sender] >= _amount);
        require(_unitPrice > 0);
        saleOffersByAddress[msg.sender] = saleOffersCounter;
        saleOffersById[saleOffersCounter] = msg.sender;
        saleOffersAmount[saleOffersCounter] = _amount;
        saleOffersUnitPrice[saleOffersCounter] = _unitPrice; //price in tinybar
        emit SetToSale(msg.sender, saleOffersCounter, _amount, _unitPrice);
        saleOffersCounter ++;
    }
    
    function buyFromSeller(uint _amount, uint _offerId) public payable {
        require(saleOffersAmount[_offerId] >= _amount);
        uint orderPrice = _amount * saleOffersUnitPrice[_offerId];
        require(msg.value == orderPrice);
        saleOffersAmount[_offerId] -= _amount;
        _transfer(saleOffersById[_offerId], msg.sender, _amount);
        uint sellersShare = orderPrice * 99 / 100;
        uint toSend = sellersShare;
        sellersShare = 0;
        address to = saleOffersById[_offerId];
        to.transfer(toSend);
        priceETH = saleOffersUnitPrice[_offerId];
        priceUSD = priceETH / ETHUSDprice;
        emit TokenBoughtFromSeller(msg.sender, saleOffersById[_offerId], _amount, _offerId);
        if(priceUSD >= dailyUpperBound) {
            mintAtUpperBound(_amount);
        }
    }
    
    function approveTx(address _to, uint _sum) public {
        toTransfers.push(ToTransfer(msg.sender, _to, _sum));
        emit TxApproval(msg.sender, _to, _sum, toTransferCounter);
        toTransferCounter ++;
    }
    
    function getApprovedTx(uint _id) public view returns(address, address, uint) {
        return(toTransfers[_id].tokenFrom, toTransfers[_id].tokenTo, toTransfers[_id].tokenAmount);
    }
    
    function transferById(uint _transferId) public {
        _transfer(toTransfers[_transferId].tokenFrom, toTransfers[_transferId].tokenTo, toTransfers[_transferId].tokenAmount);
        toTransfers[_transferId].tokenAmount = 0;
    }
    
    function transferByIdPartly(uint _transferId, uint _amount) public {
        require(toTransfers[_transferId].tokenAmount >= _amount);
        _transfer(toTransfers[_transferId].tokenFrom, toTransfers[_transferId].tokenTo, _amount);
        toTransfers[_transferId].tokenAmount -= _amount;
    }
    */
    
    function approve(address _spender, uint _sum) public {
        approvedTransfers[msg.sender][_spender] += _sum;
        emit ApproveTransfer(msg.sender, _spender, _sum);
    }
    
    function allowance(address _from, address _to) public view returns(uint) {
        return (approvedTransfers[_from][_to]);
    }
    
    function transferFrom(address _from, address _to, uint _sum) public {
        require(approvedTransfers[_from][msg.sender] >= _sum);
        approvedTransfers[_from][msg.sender] -= _sum;
        _transfer(_from, _to, _sum);
    }
    
    //Using function overload
    function transferFrom(address _from, address _to, uint _sum, uint _interestRate, bool _isRedeem) public {
        require(_isRedeem);
        require(approvedTransfers[_from][msg.sender] >= _sum);
        approvedTransfers[_from][msg.sender] -= _sum;
        _transfer(_from, _to, _sum);
        mintByRedeem(_sum, _interestRate); 
    }
    
    //_priceETH in wei, _priceUSD and _ETHUSDprice in 0.01 USD cent
    function setPrice(uint _priceUSD, uint _priceETH, uint _ETHUSDprice) public onlyServer {
       priceUSD = _priceUSD;
       priceETH = _priceETH; 
       ETHUSDprice = _ETHUSDprice;
    }
    
    //DailyBasePrice is calculated in USD
    function setDailyBasePrice(uint _price) public onlyServer() {
        require(now > lastDailyLimitUpdate + 86400);
        uint lastBasePrice = dailyBasePrice;
        dailyUpperBound = lastBasePrice * 102 / 100;
        dailyLowerBound = lastBasePrice * 98 / 100;
        
        if(_price <= dailyUpperBound && _price >= dailyLowerBound) {
            dailyBasePrice = _price;
        } else if (_price > dailyUpperBound) {
            dailyBasePrice = dailyUpperBound;
        } else {
            dailyBasePrice = dailyLowerBound;
        }
    }
    
    //_priceETH in wei _priceUSD and _ETHUSDprice in 0.01 USD cent
    function checkPrice(uint _priceUSD, uint _priceETH, uint _ETHUSDprice, uint _txAmount) public onlyServer {
        uint USDpriceFromETH = _priceETH * _ETHUSDprice / fromWeiToEth;
        priceUSD = _priceUSD;
        priceETH = _priceETH;
        ETHUSDprice = _ETHUSDprice;
        if(_priceUSD >= dailyUpperBound || USDpriceFromETH >= dailyUpperBound) {
            mintAtUpperBound(_txAmount);
            priceUSD = dailyUpperBound;
            priceETH = dailyUpperBound * fromWeiToEth / ETHUSDprice;
        }
        if(_priceUSD <= dailyLowerBound || USDpriceFromETH <= dailyLowerBound) {
            buyBackOrder(_txAmount);
            priceUSD = dailyLowerBound;
            priceETH = dailyLowerBound * fromWeiToEth / ETHUSDprice;
        }
    }
    
    function buyBackOrder(uint _txAmount) public onlyServer() {
        if(address(this).balance > 0) {
            if(address(this).balance > ETHToBuyBack) {
                buyBackOffers.push(BuyBackOffer(dailyLowerBound, _txAmount));
                buyBackOfferCounter++;
                ETHToBuyBack += _txAmount * dailyLowerBound * fromWeiToEth / ETHUSDprice;
            }
        }
    }
    
    function buyBack(uint _txAmount, uint _buyBackOfferId) public {
        require(_txAmount <= buyBackOffers[_buyBackOfferId].amount);
        //require(allowance(msg.sender, address(this)) >= _txAmount);
        //transferFrom(msg.sender, address(this), _txAmount);
        uint ETHToSend = _txAmount * buyBackOffers[_buyBackOfferId].price * fromWeiToEth / ETHUSDprice;
        require(ETHToSend <= ETHToBuyBack);
        _transfer(msg.sender, address(this), _txAmount);
        buyBackOffers[_buyBackOfferId].amount -= _txAmount;
        ETHToBuyBack -= ETHToSend;
        address to = msg.sender;
        to.transfer(ETHToSend);
    }
    
    function transferFromContract(address _addr, uint _amount) public operator() {
        _transfer(address(this), _addr, _amount);
    }
    
    function approveToAllAddress(uint _sum, address _spender) public {
        uint addressCount = tui.getUserAddressCount(msg.sender); //should create this function
        uint user = tui.getUserByAddress(msg.sender);
        for(uint i = 0; i < addressCount; i++) {
            address currentAddress = tui.getUsersAddress(user, i);
            approvedTransfers[currentAddress][_spender] += _sum;
            emit ApproveTransfer(currentAddress, _spender, _sum);
        }
    }
}
