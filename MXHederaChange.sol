pragma solidity >=0.4.25;
import "./AddressUtils.sol";

contract ERC20Interface {
    function allowance(address _from, address _to) public view returns(uint);
    function transferFrom(address _from, address _to, uint _sum) public;
    function transfer(address _to, uint _sum) public;
    function getTokenBalance(address _owner) public view returns(uint);
    function getPrices() public view returns(uint, uint, uint);
 }

contract MXHederaChange {
    
    event ConvertToHederaMX(address indexed _buyer, uint indexed _amount);
    event ConvertFromHederaMX(address indexed _seller, uint indexed _amount);
    event TokenBought(address indexed _buyer, uint _sum);
    
    address public MXAddress = ...;
    ERC20Interface mxi = ERC20Interface(MXAddress);
    address public owner;
    
    constructor() public {
        owner = msg.sender;
        //servers.push(msg.sender);
    }
    
    modifier onlyServer() {
        require(msg.sender == owner);
        _;
    }

    //Convert between blockchains
    function convertToHederaMX(address _buyer, uint _amount) public onlyServer {
       require(getTokenBalance(address(this)) >= _amount);
       require(mxi.allowance(address(this), _buyer) >= _amount);
       mxi.transferFrom(address(this), _buyer, _amount); 
       emit ConvertToHederaMX(_buyer, _amount);
    }
    
    function convertFromHederaMX(uint _amount) public {
       require(getTokenBalance(msg.sender) >= _amount);
       require(mxi.allowance(msg.sender, address(this)) >= _amount);
       mxi.transferFrom(msg.sender, address(this), _amount);
       emit ConvertFromHederaMX(msg.sender, _amount);
    }
    
    function buyToken(uint _sum) public payable {
        require(getTokenBalance(address(this)) >= _sum);
        uint priceHbar;
        (,priceHbar,) = mxi.getPrices();
        uint price = _sum * priceHbar * 101 / 100;
        require(msg.value == price);
        mxi.transfer(msg.sender, _sum);
        emit TokenBought(msg.sender, _sum);
    }
    
    function sellToken(uint _sum) public {
        uint priceHbar;
        (,priceHbar,) = mxi.getPrices();
        uint price = _sum * priceHbar * 99 / 100;
        require(getTokenBalance(msg.sender) >= _sum);
        require(mxi.allowance(msg.sender, address(this)) >= _sum);
        mxi.transferFrom(msg.sender, address(this), _sum);
        msg.sender.transfer(price);
        emit TokenBought(msg.sender, _sum);
    }
}
