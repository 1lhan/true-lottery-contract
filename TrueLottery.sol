// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TrueLottery {
    address public owner;

    constructor () {
        owner = msg.sender;
    }

    struct Lottery {
        uint256 id;
        uint256 startDate;
        uint256 endDate;
        uint256 ticketPrice;
        uint256 ticketCount;
        uint256 prizePool;
        mapping(address => uint256) participants;
        address[] participantAddresses;
        uint256 participantCount;
        address winner; 
    }

    Lottery[] public lotteries;
    uint256 public lotteryCount;

    modifier onlyOwner {
        require(msg.sender == owner, "Only the contract owner call call this function.");
        _;
    }

    modifier isLotteryIdValid (uint256 _lotteryId) {
        require(_lotteryId < lotteryCount, "Invalid ID does not exist.");
        _;
    }

    function getLottertyParticipantTicketCount (uint256 _lotteryId, address _participantAddress) public view isLotteryIdValid(_lotteryId) returns(uint256){
        return lotteries[_lotteryId].participants[_participantAddress];
    }

    function getLottertyParticipantAddresses (uint256 _lotteryId) public view isLotteryIdValid(_lotteryId) returns(address[] memory){
        return lotteries[_lotteryId].participantAddresses;
    }

    function getLottertyWinner (uint256 _lotteryId) public view isLotteryIdValid(_lotteryId) returns(address){
        return lotteries[_lotteryId].winner;
    }

    function createLottery (uint256 _startDate, uint256 _endDate, uint256 _ticketPrice) public onlyOwner {
        if(lotteryCount > 0) {
            Lottery storage lottery = lotteries[lotteryCount - 1];
            require(block.timestamp > lottery.endDate, "The lottery is still active.");
        }
        require(_ticketPrice > 0, "Ticket price must be greater than zero.");
        require(_endDate > block.timestamp, "End date must be in the future.");

        lotteries.push();
        Lottery storage newLottery = lotteries[lotteryCount];
        
        newLottery.id = lotteryCount;
        newLottery.startDate = _startDate;
        newLottery.endDate = _endDate;
        newLottery.ticketPrice = _ticketPrice;
        newLottery.ticketCount = 0;
        newLottery.prizePool = 0;

        lotteryCount++;
    }

    function buyTickets (uint256 _lotteryId, uint256 _ticketCount) public payable isLotteryIdValid(_lotteryId) {
        Lottery storage lottery = lotteries[_lotteryId];

        require(block.timestamp > lottery.startDate, "Lottery has not been started.");
        require(block.timestamp < lottery.endDate, "Lottery has been expired.");
        require(lottery.ticketPrice * _ticketCount == msg.value, "The sent amount is not equal to the ticket price times the ticket count.");
        require(_ticketCount > 0, "Ticket count must be greater than zero.");

        if(lottery.participants[msg.sender] == 0) lottery.participantAddresses.push(msg.sender);
        lottery.participants[msg.sender] += _ticketCount;
        lottery.ticketCount += _ticketCount;
    }

    function drawWinner(uint256 _lotteryId) public onlyOwner isLotteryIdValid(_lotteryId) {
        Lottery storage lottery = lotteries[_lotteryId];

        require(block.timestamp > lottery.endDate, "Lottery has not ended.");
        require(lottery.ticketCount > 0, "No tickets have been sold for this lottery.");

        lottery.prizePool = lottery.ticketPrice * lottery.ticketCount;

        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, lottery.ticketCount))) % lottery.ticketCount; /* ! */

        uint256 cumulativeTickets = 0;
        address winner;

        for (uint256 i = 0; i < lottery.participantAddresses.length; i++) {
            address participant = lottery.participantAddresses[i];

            uint256 tickets = lottery.participants[participant];

            cumulativeTickets += tickets;

            if (cumulativeTickets > randomIndex) {
                winner = participant;
                break;
            }
        }

        lottery.winner = winner;
        uint256 fee = lottery.prizePool / 100; // %1 fee
        uint256 amountToSend = lottery.prizePool - fee;

        sendEther(payable(winner), amountToSend);
    }

    function sendEther(address payable _to, uint256 _amount) public onlyOwner{
        require(_amount <= address(this).balance, "Insufficient balance");

        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    receive() external payable {}
}