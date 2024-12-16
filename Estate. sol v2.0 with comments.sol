//SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

contract EstateAgency {

    // Объявление структуры объекта недвижимости
    struct Estate {
        address owner;
        string info;
        uint square;
        bool presentSTAT;
        bool saleSTAT;
        bool arestSTAT;
    }

    // Объявление структуры сущности безвозмездной передачи
    struct Present {
        uint estateID;
        address adrFrom;
        address adrTo;
        uint deadline;
        presentSTAT status;
    }

    // Объявление структуры сущности продажи
    struct Sale{
        uint estateID;
        address owner;
        address newOwner;
        uint price;
        address[] customers;
        uint[] bids;
    }
    
    // Набор состояний сущности безвозмездной передачи
    enum presentSTAT {
        ACTIVE,
        REFUSE,
        ACCEPT,
        CANCEL,
        RECONSIDER
    }

    // Объявление списков структур описанных сущностей
    Estate[] public estates;
    Present[] public presents;
    Sale[] public sales;

    // Объявление адреса администратора системы
    address public admin;

    // Время на принятие решения по безвозмездной передаче недвижимости
    uint public presentTime = 60;

    // Модификатор, позволяющий только администратору системы вызывать метод контракта
    modifier isAdmin() {
        require(msg.sender == admin, "You are not admin");
        _;
    }

    // Модификатор, позволяющий только владельцу объекта недвижимости вызывать метод контракта
    modifier onlyOwner(uint estateID) {
        require(estates[estateID].owner == msg.sender, "It's not your estate!");
        _;
    }

    // Модификатор, проверяющий статусы объекта недвижимости перед действием с ним
    modifier statusOK(uint estateID) {
        require(estates[estateID].presentSTAT == false, "Already in present");
        require(estates[estateID].saleSTAT == false, "Already in sale");
        require(estates[estateID].arestSTAT == false, "Estate in arest");
        _;
    }

    // В конструкторе задаем адрес администратора системы
    // Вариант 1 - по умолчанию, автор смарт-контракта
    // Вариант 2 - явно, как параметр при деплое
    constructor(address _adminAdr) {
        // Var 1
        //admin = msg.sender;

        // Var 2
        admin = _adminAdr;
    }

    // Функционал администратора

    // Создание объекта недвижимости
    function createEstate(address _owner, string memory _info, uint _square) public isAdmin {
        require(_owner != address(0), "Wrong address!");
        require(_square > 0, "Wrong quiare value");
        estates.push(Estate(_owner, _info, _square, false, false, false));
    }

    // Смена статуса ареста объекта недвижимости
    function changeArestSTAT(uint estateID, bool _newArestSTAT) public isAdmin {
        require(_newArestSTAT != estates[estateID].arestSTAT, "The same arestSTAT");
        estates[estateID].arestSTAT = _newArestSTAT;
    }

    // Функционал по безвозмездной передаче объекта недвижимости

    // Создать сущность безвозмездной передачи объекта недвижимость конкретному пользователю
    function createPresent(uint estateID, address _adrTo) public statusOK(estateID) onlyOwner(estateID) {
        require(_adrTo != address(0), "Wrong address");
        require(estateID < estates.length, "Wrong estateID value");
        require(_adrTo != msg.sender, "Selfpresenting!");
        presents.push(Present(estateID, msg.sender, _adrTo, presentTime + block.timestamp, presentSTAT.ACTIVE));
        estates[estateID].presentSTAT = true;
    }

    // Отменить процесс передачи объекта недвижимости до того, как получатель примет права на него
    // Если владелец не успел сделать это в течение заявленного времени, то сущность потеряет актуальность
    function reconsiderPresent(uint presentID) public {
        require(presentID < presents.length, "Wrong estateID!");
        require(presents[presentID].status == presentSTAT.ACTIVE, "Already finished");
        require(presents[presentID].adrFrom == msg.sender, "You are not owner!");
        uint estateID = presents[presentID].estateID;
        if (presents[presentID].deadline > block.timestamp) {
            presents[presentID].status = presentSTAT.RECONSIDER;
        }
        else {
            presents[presentID].status = presentSTAT.CANCEL;
        }
        estates[estateID].presentSTAT = false;
    }

    // Принять права на объект недвижимости
    // Если получатель не успел сделать это в течение заявленного времени, то сущность потеряет актуальность
    function acceptPresent(uint presentID) public {
        uint estateID = presents[presentID].estateID;
        require(estates[estateID].arestSTAT == false, "Estate in arest");
        require(presentID < presents.length, "Wrong estateID!");
        require(presents[presentID].status == presentSTAT.ACTIVE, "Already finished");
        require(presents[presentID].adrTo == msg.sender, "This is not for you!");
        
        if (presents[presentID].deadline > block.timestamp) {
            presents[presentID].status = presentSTAT.ACCEPT;
            estates[estateID].owner = msg.sender;
        }
        else {
            presents[presentID].status = presentSTAT.CANCEL;
        }
        estates[estateID].presentSTAT = false;
    }

    // Отказаться от получения прав на объект недвижимости
    // Если получатель не успел сделать это в течение заявленного времени, то сущность потеряет актуальность
    function refusePresent(uint presentID) public {
        uint estateID = presents[presentID].estateID;
        require(presentID < presents.length, "Wrong estateID!");
        require(presents[presentID].status == presentSTAT.ACTIVE, "Already finished");
        require(presents[presentID].adrTo == msg.sender, "This is not for you!");
        if (presents[presentID].deadline > block.timestamp) {
            presents[presentID].status = presentSTAT.REFUSE;
        }
        else {
            presents[presentID].status = presentSTAT.CANCEL;
        }
        estates[estateID].presentSTAT = false;
    }

    // Функционал по продаже объектов недвижимости

    // Создать сущность продажи объекта недвижимости
    function createSale(uint estateID, uint _price) public statusOK(estateID) onlyOwner(estateID) {
        require(estateID < estates.length, "Wrong estateID!");
        require(_price > 10**9 wei);
        address[] memory _customers;
        uint[] memory _bids;
        sales.push(Sale(estateID, msg.sender, address(0), _price, _customers, _bids));
        estates[estateID].saleSTAT = true;
    }

    // Сделать ценовое предложение по конкретной продаже, перевести деньги на счет контракта, как посредника в процессе продажи
    function makeBid(uint saleID) public payable {
        uint estateID = sales[saleID].estateID;
        require(estates[estateID].arestSTAT == false); 
        require(saleID < sales.length, "Wrong saleID value");
        require(sales[saleID].owner != msg.sender, "Selfsaling");
        require(sales[saleID].newOwner == address(0), "Sale is closed");
        require(sales[saleID].price <= msg.value, "Wrong ether value");
        
        // Проверка на наличие ранее сделанных ставок, ставки не обновляются
        // Два варианта
        // Var 1
        /*
        for (uint i = 0; i < sales[saleID].customers.length; i++) {
            if (sales[saleID].customers[i] == msg.sender) {
                require(false, "You have already made a bid");
            }
        }
        */
        // Var 2
        bool stat = false;
        for (uint i = 0; i < sales[saleID].customers.length; i++) {
            if (sales[saleID].customers[i] == msg.sender) {
                stat = true;
                break;
            }
        }
        require(stat == false, "You have already made a bid");

        sales[saleID].customers.push(msg.sender);
        sales[saleID].bids.push(msg.value);
    }
    
    // Отказаться от покупки объекта недвижимости и обнулить свое ценовое предложение, вернуть деньги покупателю из контракта
    function refuseBid(uint saleID) public payable {
        require(saleID < sales.length, "Wrong saleID value");
        require(sales[saleID].newOwner == address(0), "Sale is closed");
        for (uint i = 0; i < sales[saleID].customers.length; i++) {
            if (sales[saleID].customers[i] == msg.sender) {
                uint bid = sales[saleID].bids[i];
                require(bid != 0, "Your bid is 0");
                payable(msg.sender).transfer(sales[saleID].bids[i]);
                sales[saleID].bids[i] = 0;
                break;
            }
        }
    }

    // Принять ценовое предложение и передать права на объект недвижимости, получить деньги с кошелька контракта согласно выбранному предложению
    // При этом остальные предложения возвращаются с кошелька смарт-контракта обратно пользователям
    function acceptBid(uint saleID, uint bidID) public payable {
        uint estateID = sales[saleID].estateID;
        require(estates[estateID].arestSTAT == false, "Estate in arest");
        require(saleID < sales.length, "Wrong saleID value");
        require(sales[saleID].newOwner == address(0), "Sale is closed");
        require(sales[saleID].owner == msg.sender, "Not you sale");
        for (uint i = 0; i < sales[saleID].customers.length; i++) {
            if (i != bidID) {
                payable(sales[saleID].customers[i]).transfer(sales[saleID].bids[i]);
            }
            else {
                payable(sales[saleID].owner).transfer(sales[saleID].bids[bidID]);
                sales[saleID].newOwner = sales[saleID].customers[bidID];
                estates[estateID].owner = sales[saleID].customers[bidID];
            }
        }
        estates[estateID].saleSTAT = false;
    }

    // Отказаться от продажи объекта недвижимости
    // Все предложения будут возвращены согласно спискам с кошелька смарт-контракта на балансы пользователей
    function reconsiderSale(uint saleID) public payable {
        uint estateID = sales[saleID].estateID;
        require(saleID < sales.length, "Wrong saleID value");
        require(sales[saleID].newOwner == address(0), "Sale is closed");
        require(sales[saleID].owner == msg.sender, "Not you sale");
        for (uint i = 0; i < sales[saleID].customers.length; i++) {
            payable(sales[saleID].customers[i]).transfer(sales[saleID].bids[i]);
        }
        sales[saleID].newOwner = msg.sender;
        estates[estateID].saleSTAT = false;
    }

    // Получить список аккаунтов, которые хотели бы купить предлагаемый объект недвижимости
    function getCustomerList(uint saleID) public view returns(address[] memory) {
        return sales[saleID].customers;
    }  

    // Получить список ценовых предложений, который сделали пользователи из списка customers для данной сущности продажи
    function getBidList(uint saleID) public view returns(uint[] memory) {
        return sales[saleID].bids;
    }    

}