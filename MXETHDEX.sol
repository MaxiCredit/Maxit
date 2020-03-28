pragma solidity >=0.4.25;
import "./AddressUtils.sol";

contract ERC20Interface {
    function allowance(address _from, address _to) public view returns(uint);
    function transferFrom(address _from, address _to, uint _sum) public;
    function transfer(address _to, uint _sum) public;
    function balanceOf(address _owner) public view returns(uint);
    function decimals() public view returns(uint8);
    function checkPrice(uint _priceUSD, uint _priceETH, uint _ETHUSDprice, uint _txAmount) public;
}

contract MXETHDEX {
    
    event SetOrderETHBid(uint indexed _orderId, uint _amount, uint _price, uint _lastTo);
    event SetOrderETHAsk(uint indexed _orderId, uint _amount, uint _price, uint _lastTo);
    event SetOrderERC20(uint indexed _orderType, uint indexed _orderId, uint _amount, uint _price, uint _lastTo, address _currencyAddress);
    event DeleteOrder(uint indexed _orderId);
    event AcceptETHBid(uint indexed _orderId, uint _amount);
    event AcceptETHAsk(uint indexed _orderId, uint _amount);
    event AcceptERC20Bid();
    event AcceptERC20Ask();
    
    //enum OfferType {Bid, Ask}
    //enum CurrencyType {ETH, ERC20}
    uint Bid = 0;
    uint Ask = 1;
    uint ETH = 0;
    uint ERC20 = 1;
    
    using AddressUtils for address;
    address public owner;
    mapping(address => mapping(uint => uint)) public ordersByAddress;
    mapping(address => uint) public orderNumberByAddress;
    address public MXAddress;
    ERC20Interface mxi;
    
    uint public latestUSDprice;
    uint public latestETHprice;
    uint public latestETHUSDprice;

    struct Order {
        uint orderType;
        uint orderCurrencyType;
        uint orderAmount;
        uint orderPrice;
        uint orderLastTo;
        address orderCurrencyAddress;
        address orderOwner;
        uint ETHBalance;
    }
    
    Order[] public orders;
    uint public orderCounter;
    uint orderId;
    
    constructor(uint _latestUSDprice, uint _latestETHprice, uint _latestETHUSDprice) public {
        owner = msg.sender;
        latestUSDprice = _latestUSDprice;
        latestETHprice = _latestETHprice;
        latestETHUSDprice = _latestETHUSDprice;
    }
    
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    
    modifier onlyOwnerOf(uint _id) {
        require(orders[_id].orderOwner == msg.sender);
        _;
    }
    
    function setMXAddress(address _addr) public onlyOwner {
        require(_addr != address(0));
        MXAddress = _addr;
        mxi = ERC20Interface(_addr);
    }
    
    function getMXallowance(address _from, address _to) public view returns(uint) {
        //return mxi.allowance(_from, _to);
        uint allow = mxi.allowance(_from, _to);
        return allow;
    }
    
    function setOrderETHBid(uint _amount, uint _price, uint _lastTo) public payable {
        uint ETHBidPrice = _amount * _price;
        require(ETHBidPrice == msg.value); //take to setOrder
        orderId = orders.push(Order(Bid, ETH, _amount, _price, now + _lastTo, address(0), msg.sender, ETHBidPrice)); 
        ordersByAddress[msg.sender][orderNumberByAddress[msg.sender]] = orderId;
        orderNumberByAddress[msg.sender] ++;
        orderCounter++;
        emit SetOrderETHBid(orderId, _amount, _price, _lastTo);
    }

    function setOrderETHAsk(uint _amount, uint _price, uint _lastTo) public {
        require(mxi.allowance(msg.sender, address(this)) >= _amount); //take to setOrder
        orderId = orders.push(Order(Ask, ETH, _amount, _price, now + _lastTo, address(0), msg.sender, 0)); 
        ordersByAddress[msg.sender][orderNumberByAddress[msg.sender]] = orderId;
        orderNumberByAddress[msg.sender] ++;
        orderCounter++;
        emit SetOrderETHAsk(orderId, _amount, _price, _lastTo);
    }
    
    function setOrderERC20(uint _orderType, uint _amount, uint _price, uint _lastTo, address _currencyAddress) public {
        uint tokenDecimals = ERC20Interface(_currencyAddress).decimals();
        uint decimalMultiplier = 10 ** tokenDecimals;
        uint currentTokenPrice = _price * decimalMultiplier;
        if(_orderType == 0) {
            require(ERC20Interface(_currencyAddress).allowance(msg.sender, address(this)) >= (_amount * currentTokenPrice));
        }
        if(_orderType == 1) {
            require(mxi.allowance(msg.sender, address(this)) >= _amount);
        }

        orderId = orders.push(Order(_orderType, ERC20, _amount, _price, now + _lastTo, _currencyAddress, msg.sender, 0)); 
        ordersByAddress[msg.sender][orderNumberByAddress[msg.sender]] = orderId;
        orderNumberByAddress[msg.sender] ++;
        orderCounter++;
        emit SetOrderERC20(_orderType, orderId, _amount, _price, _lastTo, _currencyAddress);
    }
    
    function deleteOrder(uint _orderId) public onlyOwnerOf(_orderId) {
        address sendBack = orders[_orderId].orderOwner;
        if(orders[_orderId].ETHBalance > 0) {
            sendBack.transfer(orders[_orderId].ETHBalance);
            orders[_orderId].ETHBalance = 0;
        }
        orders[_orderId].orderAmount = 0;
        orders[_orderId].orderPrice = 0;
        orders[_orderId].orderLastTo = 0;
        orders[_orderId].orderOwner = address(0);
        orders[_orderId].orderCurrencyAddress = address(0);
        emit DeleteOrder(_orderId);
    }
    
    function acceptBidETH(uint _orderId, uint _amount) public {
        require((orders[_orderId].orderType) == Bid);
        require(orders[_orderId].orderCurrencyType == ETH);
        require(orders[_orderId].orderAmount >= _amount);
        require(mxi.allowance(msg.sender, address(this)) >= _amount);
        //require(orders[_orderId].orderLastTo > now);
        uint bidETHPrice = orders[_orderId].orderPrice * _amount;
        msg.sender.transfer(bidETHPrice);
        mxi.transferFrom(msg.sender, orders[_orderId].orderOwner, _amount);
        emit AcceptETHBid(_orderId, _amount);
        orders[_orderId].orderAmount -= _amount;
        orders[_orderId].ETHBalance -= bidETHPrice;
        latestETHprice = orders[_orderId].orderPrice;
        mxi.checkPrice(latestUSDprice, latestETHprice, latestETHUSDprice, _amount);
    }

    function acceptAskETH(uint _orderId, uint _amount) public payable {
        require(orders[_orderId].orderType == Ask);
        require(orders[_orderId].orderCurrencyType == ETH);
        require(orders[_orderId].orderAmount >= _amount);
        //require(orders[_orderId].orderLastTo > now);
        uint askETHPrice = orders[_orderId].orderPrice * _amount;
        require(askETHPrice == msg.value);
        address ordersOwner = orders[_orderId].orderOwner;
        ordersOwner.transfer(askETHPrice);
        mxi.transferFrom(orders[_orderId].orderOwner, msg.sender, _amount);
        emit AcceptETHAsk(_orderId, _amount);
        orders[_orderId].orderAmount -= _amount;
        latestETHprice = orders[_orderId].orderPrice;
        mxi.checkPrice(latestUSDprice, latestETHprice, latestUSDprice, _amount);
    }
        /*
 
    function acceptAskHbar(uint _orderId, uint _amount, uint _priceUSD, uint _HbarUSDprice) public view returns(uint, uint, uint, uint, uint) {
        uint askHbarPrice = orders[_orderId].orderPrice * _amount;
        
        require(orders[_orderId].orderType == Ask);
        require(orders[_orderId].orderCurrencyType == Hbar);
        require(orders[_orderId].orderAmount >= _amount);
        
        uint askHbarPrice = orders[_orderId].orderPrice * _amount;
        require(askHbarPrice == msg.value);
        address ordersOwner = orders[_orderId].orderOwner;
        ordersOwner.transfer(askHbarPrice);
        mxi.transferFrom(orders[_orderId].orderOwner, msg.sender, _amount);
        emit AcceptHbarAsk(_orderId, _amount);
        orders[_orderId].orderAmount -= _amount;
        mxi.checkPrice(_priceUSD, orders[_orderId].orderPrice, _HbarUSDprice, _amount);
        return(orders[_orderId].orderType, orders[_orderId].orderCurrencyType, orders[_orderId].orderAmount, _amount, askHbarPrice);
    }
       */
       
    //DECIMALS??
    function acceptBidERC20(uint _orderId, uint _amount) public {
        require(orders[_orderId].orderAmount >= _amount);
        require(orders[_orderId].orderType == Bid);
        require(orders[_orderId].orderCurrencyType == ERC20);
        require(mxi.allowance(msg.sender, address(this)) >= _amount);
        uint bidERC20Price = orders[_orderId].orderPrice * _amount;
        address currencyAddress = orders[_orderId].orderCurrencyAddress;
        ERC20Interface(currencyAddress).transferFrom(orders[_orderId].orderOwner, msg.sender, bidERC20Price);
        mxi.transferFrom(msg.sender, orders[_orderId].orderOwner, _amount);
        emit AcceptERC20Bid();
        orders[_orderId].orderAmount -= _amount;
        latestUSDprice = orders[_orderId].orderPrice;
        mxi.checkPrice(latestUSDprice, latestETHprice, latestETHUSDprice, _amount);
    }
    
    //DECIMALS??
    function acceptAskERC20(uint _orderId, uint _amount) public {
        require(orders[_orderId].orderAmount >= _amount);
        require(orders[_orderId].orderType == Ask);
        require(orders[_orderId].orderCurrencyType == ERC20);
        address currencyAddress = orders[_orderId].orderCurrencyAddress;
        require(ERC20Interface(currencyAddress).allowance(msg.sender, address(this)) >= _amount);
        uint askERC20Price = orders[_orderId].orderPrice * _amount;
        ERC20Interface(currencyAddress).transferFrom(msg.sender, orders[_orderId].orderOwner, askERC20Price);
        mxi.transferFrom(orders[_orderId].orderOwner, msg.sender, _amount);
        emit AcceptERC20Ask();
        orders[_orderId].orderAmount -= _amount;
        latestUSDprice = orders[_orderId].orderPrice;
        mxi.checkPrice(latestUSDprice, latestETHprice, latestETHUSDprice, _amount);
    }
}
