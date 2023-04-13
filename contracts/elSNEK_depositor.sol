/**
 *Submitted for verification at Arbiscan on 2023-03-16
*/

/**
 *Submitted for verification at BscScan.com on 2023-01-10
*/

/*

FFFFF  TTTTTTT  M   M         GGGGG  U    U  RRRRR     U    U
FF       TTT   M M M M       G       U    U  RR   R    U    U
FFFFF    TTT   M  M  M      G  GGG   U    U  RRRRR     U    U
FF       TTT   M  M  M   O  G    G   U    U  RR R      U    U
FF       TTT   M     M       GGGGG    UUUU   RR  RRR    UUUU



						Contact us at:
			https://discord.com/invite/QpyfMarNrV
					https://t.me/FTM1337

	Community Mediums:
		https://medium.com/@ftm1337
		https://twitter.com/ftm1337

	SPDX-License-Identifier: UNLICENSED


	elSNEK_Depositor.sol

	elSNEK, or le Snek🐍 is a Liquid Staking Derivate for veSNEK (Vote-Escrowed SoliSnek NFT).
	It can be minted by burning (veSNEK) veNFTs.
	elSNEK adheres to the EIP20 Standard.
	It can be staked with Guru Network to earn pure AVAX instead of multiple small tokens.
	elSNEK can be further deposited into Kompound Protocol to mint ibSNEK.
	ibSNEK is a doubly-compounding interest-bearing veSNEK at its core.
	ibSNEK uses elSNEK's AVAX yield to buyback more elSNEKs from the open-market via JIT Aggregation.
	The price (in SNEK) to mint elSNEK goes up every epoch due to positive rebasing.
	This property gives ibSNEK a "hyper-compounding" double-exponential trajectory against raw SNEK tokens.
	elSNEL is the market ticker for le Snek🐍.
	Price of 1 elSNEK is independent and not affected by the price of SNEK.

*/

pragma solidity 0.8.17;

interface IERC20 {
	function totalSupply() external view returns (uint256);
	function transfer(address recipient, uint amount) external returns (bool);
	function balanceOf(address) external view returns (uint);
	function transferFrom(address sender, address recipient, uint amount) external returns (bool);
}
interface IelSNEK is IERC20 {
	function mint(address w, uint a) external returns (bool);
}
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
interface IVotingEscrow {
	struct LockedBalance {
		int128 amount;
		uint end;
	}
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function locked(uint id) external view returns(LockedBalance memory);
	function token() external view returns (address);
	function merge(uint _from, uint _to) external;
}

contract elSNEK_Depositor {
	struct LockedBalance {
		int128 amount;
		uint end;
	}
	address public dao;
	IelSNEK public elSNEK;
	IVotingEscrow public veSNEK;
	uint public ID;
	uint public supplied;
	uint public converted;
	uint public minted;
	/// @notice ftm.guru simple re-entrancy check
	bool internal _locked;
	modifier lock() {
		require(!_locked,  "Re-entry!");
		_locked = true;
		_;
		_locked = false;
	}
	modifier DAO() {
		require(msg.sender==dao, "Unauthorized!");
		_;
	}
	event Deposit(address indexed, uint indexed, uint, uint, uint);
    function onERC721Received(address, address,  uint256, bytes calldata) external view returns (bytes4) {
        require(msg.sender == address(veSNEK), "!veToken");
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
	function deposit(uint _id) public lock returns (uint) {
		uint _ts = elSNEK.totalSupply();
		require(_ts > 0, "Uninitialized!");
		IVotingEscrow.LockedBalance memory _main = veSNEK.locked(ID);
		require(_main.amount > 0, "Stale veNFT!");
		int _ibase = _main.amount;	//pre-cast to int
		uint256 _base = uint256(_ibase);
		veSNEK.safeTransferFrom(msg.sender, address(this), _id);
		veSNEK.merge(_id,ID);
		IVotingEscrow.LockedBalance memory _merged = veSNEK.locked(ID);
		int _in = _merged.amount - _main.amount;
		require(_in > 0, "Dirty Deposit!");
		uint256 _inc = uint256(_in);//cast to uint
		supplied += _inc;
		converted++;
		// Calculate and mint the amount of elSNEK the veNFT is worth. The ratio will change overtime,
		// as elSNEK is minted when veSNEK are deposited + gained from rebases
		uint256 _amt = (_inc * _ts) / _base;
		elSNEK.mint(msg.sender, _amt);
		emit Deposit(msg.sender, _id, _inc, _amt, block.timestamp);
		minted+=_amt;
		return _amt;
	}
	// If no elSNEK exists, mint it 1:1 to the amount of THE present inside the veNFT deposited via initialize
	function initialize(uint _id) public DAO lock {
		IVotingEscrow.LockedBalance memory _main = veSNEK.locked(_id);
		require(_main.amount > 0, "Dirty veNFT!");
		require(minted == 0, "Initialized!");
		int _iamt = _main.amount;
		uint _amt = uint(_iamt);
		elSNEK.mint(msg.sender, _amt);
		ID = _id;
		supplied += _amt;
		converted++;
		minted+=_amt;
	}
	function quote(uint _id) public view returns (uint) {
		uint _ts = elSNEK.totalSupply();
		IVotingEscrow.LockedBalance memory _main = veSNEK.locked(ID);
		IVotingEscrow.LockedBalance memory _user = veSNEK.locked(_id);
		if( ! (_main.amount > 0) ) {return 0;}
		int _ibase = _main.amount;	//pre-cast to int
		uint256 _base = uint256(_ibase);
		int _in = _user.amount;
		if( ! (_in > 0) ) {return 0;}
		uint256 _inc = uint256(_in);//cast to uint
		// If no elSNEK exists, mint it 1:1 to the amount of THE present inside the veNFT deposited
		if (_ts == 0 || _base == 0) {
			return _inc;
		}
		// Calculate and mint the amount of elSNEK the veNFT is worth. The ratio will change overtime,
		// as elSNEK is minted when veSNEK are deposited + gained from rebases
		else {
			uint256 _amt = (_inc * _ts) / _base;
			return _amt;
		}
	}
	function rawQuote(uint _inc) public view returns (uint) {
		uint _ts = elSNEK.totalSupply();
		IVotingEscrow.LockedBalance memory _main = veSNEK.locked(ID);
		if( ! (_main.amount > 0) ) {return 0;}
		int _ibase = _main.amount;	//pre-cast to int
		uint256 _base = uint256(_ibase);
		// If no elSNEK exists, mint it 1:1 to the amount of SNEK present inside the veNFT deposited
		if (_ts == 0 || _base == 0) {
			return _inc;
		}
		// Calculate and mint the amount of elSNEK the veNFT is worth. The ratio will change overtime,
		// as elSNEK is minted when veSNEK are deposited + gained from rebases
		else {
			uint256 _amt = (_inc * _ts) / _base;
			return _amt;
		}
	}
	function price() public view returns (uint) {
		return 1e36 / rawQuote(1e18);
	}
	function setDAO(address d) public DAO {
		dao = d;
	}
	function setID(uint _id) public DAO {
		ID = _id;
	}
	function rescue(address _t, uint _a) public DAO lock {
		IERC20 _tk = IERC20(_t);
		_tk.transfer(dao, _a);
	}
	constructor(address ve, address e) {
		dao=msg.sender;
		veSNEK = IVotingEscrow(ve);
		elSNEK = IelSNEK(e);
	}
}

/*
	Community, Services & Enquiries:
		https://discord.gg/QpyfMarNrV

	Powered by Guru Network DAO ( 🦾 , 🚀 )
		Simplicity is the ultimate sophistication.
*/