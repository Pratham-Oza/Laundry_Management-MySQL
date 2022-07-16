SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
DROP DATABASE Laundry; -- to recreate the database everytime this file is executed
START TRANSACTION;
CREATE DATABASE Laundry;
use laundry;
SET time_zone = "+00:00";

-- Table structure for table `Stations`
CREATE TABLE `Stations` (
   `StationID` int NOT NULL PRIMARY KEY AUTO_INCREMENT,
   `Service` varchar(255) NOT NULL,
   `Capacity` double NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table structure for table `Customers`
CREATE TABLE `Customers` (
  `CustomerId` int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `CustomerName` varchar(255),
  `date_created` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- Table structure for table `Garments`
CREATE TABLE `Garments` (
  `Garment` varchar(255),
  `Service` varchar(255),
  `Days` int NOT NULL,
  `Price` double NOT NULL,
  CONSTRAINT gar_ser PRIMARY KEY (Garment,Service)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table structure for table `Orders`

CREATE TABLE `Orders` (
  `OrderID` int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `CustomerID` int NOT NULL,
  `date_created` datetime NOT NULL DEFAULT current_timestamp(),
  FOREIGN KEY(CustomerID) REFERENCES Customers(CustomerID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table structure for table `OrderDetails`

CREATE TABLE `OrderDetails` (
   `SubOrderID` int NOT NULL PRIMARY KEY AUTO_INCREMENT,
   `OrderID` int NOT NULL,
   `Garment` varchar(255) NOT NULL,
   `Service` varchar(255) NOT NULL,
   `Quantity` int NOT NULL,
   `OrderStatus` INT DEFAULT 0 -- 0: Not started, 1: in progress, 2: Completed
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `StationDetails`(
	`StationID` int NOT NULL,
    `SubOrderID` int NOT NULL,
    `date_created` datetime NOT NULL DEFAULT current_timestamp(),
    FOREIGN KEY(StationID) REFERENCES OrderDetails(SubOrderID),
    CONSTRAINT sta_sub PRIMARY KEY (StationID, SubOrderID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `Finances`(
    `SubOrderID` int NOT NULL,
    `Price` int NOT NULL,
    FOREIGN KEY(SubOrderID) REFERENCES OrderDetails(SubOrderID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


COMMIT;

-- Inserting dummy data for testing in all tables

-- START TRANSACTION;

-- INSERT INTO stations(service, capacity) values
-- ('machine wash', 20),
-- ('machine wash', 10),
-- ('hand wash', 20),
-- ('hand wash', 10),
-- ('dry clean', 10),
-- ('dry clean', 5);

-- INSERT INTO garments(garment, service, days, price) values
-- ('shirt', 'machine wash', 1, 5),
-- ('shirt', 'hand wash', 1, 7),
-- ('shirt', 'dry clean', 2, 10),
-- ('tshirt', 'machine wash', 1, 4),
-- ('tshirt', 'hand wash', 1, 6),
-- ('tshirt', 'dry clean', 2, 9),
-- ('undergarments', 'machine wash', 1, 5),
-- ('undergarments', 'hand wash', 1, 7),
-- ('pants', 'machine wash', 1, 6),
-- ('pants', 'hand wash', 1, 8),
-- ('pants', 'dry clean', 2, 11),
-- ('jacket', 'dry clean', 2, 20),
-- ('blanket', 'dry clean', 2, 30),
-- ('dress', 'machine wash', 1, 5),
-- ('dress', 'hand wash', 1, 7),
-- ('dress', 'dry clean', 2, 10);

-- INSERT INTO customers(CustomerName) values
-- ('Rahul'),
-- ('Nikhil'),
-- ('Suresh'),
-- ('Nikita'),
-- ('Amit');


-- INSERT INTO orders(customerid) values
-- (1),
-- (1),
-- (2),
-- (3),
-- (4);

-- INSERT INTO orderdetails(orderid, garment, service, quantity) values
-- (1, 'shirt', 'hand wash', 3),
-- (1, 'tshirt', 'hand wash', 2),
-- (1, 'undergarments', 'machine wash', 4),
-- (2, 'jacket', 'dry clean', 1),
-- (2, 'pants', 'dry clean', 1),
-- (3, 'pants', 'machine wash', 2),
-- (3, 'shirt', 'machine wash', 2),
-- (4, 'dress', 'dry clean', 3),
-- (4, 'undergarments', 'machine wash', 3),
-- (5, 'jacket', 'dry clean', 2);

-- INSERT INTO StationDetails(stationid, suborderid) values
-- (3, 1),
-- (4, 2),
-- (1, 3),
-- (5, 4),
-- (5, 5),
-- (1, 6),
-- (1, 7),
-- (5, 8),
-- (2, 9),
-- (6, 10);

-- INSERT INTO Finances(suborderid, price) values
-- (1, 21),
-- (2, 12),
-- (3, 20),
-- (4, 20),
-- (5, 11),
-- (6, 10),
-- (7, 10),
-- (8, 30),
-- (9, 15),
-- (10, 40);

-- COMMIT;

-- Procedures
DELIMITER $$
CREATE PROCEDURE GetCustomerStatus (CustID int)         
    LANGUAGE SQL  
BEGIN
	START TRANSACTION;
	SELECT Garment, Service, Quantity, 
    CASE
		WHEN OrderStatus = 0 THEN 'PENDING'
        WHEN OrderStatus = 1 THEN 'IN PROGRESS'
        WHEN OrderStatus = 2 THEN 'COMPLETED'
	END AS `Status`
    FROM OrderDetails WHERE
    OrderID in (SELECT OrderID FROM Orders
				WHERE CustomerID = CustID);
    COMMIT;
END$$
DELIMITER ;

DELIMITER $$
CREATE FUNCTION StartNewOrder (CustID int, CustName varchar(255)) RETURNS int
READS SQL DATA
BEGIN 
	DECLARE CustIDIn int;
    SET @CustIDIn = CustID;
	IF CustID NOT IN (SELECT CustomerID FROM CUSTOMERS)
    THEN
		INSERT INTO Customers(CustomerName) values(CustName);
        SET @CustID = (SELECT CustomerID FROM Customers where CustomerID = last_insert_id());
        SET @CustIDIn = @CustID;
	END IF;
    INSERT INTO Orders(CustomerID) values (@CustIDIn);
	SET @OrderIDLast = (SELECT OrderID FROM Orders where OrderID = last_insert_id());
    RETURN @OrderIDLast;
END$$;

DELIMITER $$
CREATE PROCEDURE SubmitWashPerItem (CreatedOrderID int, RequestedGarment varchar(255), RequestedService varchar(255), quantity int)
    LANGUAGE SQL  
BEGIN 
	START TRANSACTION;
	IF (SELECT COUNT(garment) FROM (SELECT garment, service FROM GARMENTS WHERE garment = RequestedGarment AND service = RequestedService) AS T) = 1
    THEN
		INSERT INTO OrderDetails(OrderID, Garment, Service, Quantity) values
		(CreatedOrderID, RequestedGarment, RequestedService, quantity); 
		SET @SubOrderIDLast = (SELECT SubOrderID FROM OrderDetails where SubOrderID = last_insert_id());
		SET @Price = (SELECT Price*Quantity FROM GARMENTS 
					  RIGHT JOIN OrderDetails
					  ON OrderDetails.Garment = Garments.Garment AND OrderDetails.Service = Garments.Service
					  WHERE SubOrderID = @SubOrderIDLast);
		INSERT INTO FINANCES(SubOrderID, Price) values
		(@SubOrderIDLast, @Price);
	ELSE
		SELECT 'Combination Unavailable' AS '';
	END IF;
	COMMIT;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE GetServiceDetails ()
    LANGUAGE SQL  
    DETERMINISTIC
BEGIN 
	START TRANSACTION;
		SELECT * FROM Garments;
	COMMIT;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE GetPriceOfOrder (SubmittedOrderID int)
    LANGUAGE SQL  
BEGIN 
	START TRANSACTION;
	SELECT OrderID, SUM(Price*Quantity) AS TotalAmount FROM Garments
	RIGHT JOIN  OrderDetails
	ON OrderDetails.Garment = Garments.Garment AND OrderDetails.Service = Garments.Service
    WHERE OrderID = SubmittedOrderID
    GROUP BY OrderID;
	COMMIT;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE UpdateStatus (RequestedSubOrderID int, newStatus int)
    LANGUAGE SQL  
BEGIN 
	START TRANSACTION;
	UPDATE OrderDetails
    SET OrderStatus = newStatus
    WHERE SubOrderID = RequestedSubOrderID;
	COMMIT;
END$$
DELIMITER ; 

DELIMITER $$
CREATE PROCEDURE AssignToStation (RequestedSubOrderID int, RequestedStationID int)
    LANGUAGE SQL  
BEGIN
	START TRANSACTION;
	SET @quantity = (SELECT SUM(Quantity) FROM StationDetails 
					INNER JOIN OrderDetails
					ON OrderDetails.SubOrderID = StationDetails.SubOrderID
					WHERE StationDetails.StationID = RequestedStationID AND OrderDetails.SubOrderID != RequestedSubOrderID);
	SET @capacity = (SELECT Capacity FROM STATIONS WHERE StationID = RequestedStationID);
    SET @required = (SELECT Quantity FROM OrderDetails WHERE SubOrderID = RequestedSubOrderID);
    IF COALESCE(@quantity, 0) + @required <= @capacity 
    THEN
		INSERT INTO StationDetails(StationID, SubOrderID) value(RequestedStationID, RequestedSubOrderID);
		call UpdateStatus(RequestedSubOrderID, 1);
	ELSE
		SELECT 'Not Enough Space in the Requested Station' AS '', 
				COALESCE(@required, 'Station Does Not Exist, ignore subsequent values') as Requested, 
                COALESCE(@quantity, 'Station Does Not Exist, ignore subsequent values') as 'In Use', 
                COALESCE(@capacity, 'Station Does Not Exist, ignore subsequent values')  as Capacity;
	END IF;

	COMMIT;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE FreeStation (RequestedSubOrderID int, RequestedStationID int)
    LANGUAGE SQL  
BEGIN 
	START TRANSACTION;
	DELETE FROM StationDetails
    WHERE SubOrderID = RequestedSubOrderID AND StationID = RequestedStationID;
    call UpdateStatus(RequestedSubOrderID, 2);
	COMMIT;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE ShowPending ()
    LANGUAGE SQL
BEGIN 
	START TRANSACTION;
		SELECT SubOrderID, Garment, OrderDetails.Service, Quantity, Stations.StationID as 'Possible Stations' FROM OrderDetails 
		LEFT JOIN Stations
		ON Stations.service = OrderDetails.service
		WHERE OrderStatus = 0
		ORDER BY service;
	COMMIT;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE GetFinances ()
    LANGUAGE SQL  
BEGIN 
	START TRANSACTION;
		SELECT * FROM Finances;
	COMMIT;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE GetStationDetails ()
    LANGUAGE SQL  
BEGIN 
	START TRANSACTION;
		SELECT * FROM StationDetails;
	COMMIT;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE GetETA (RequestedCustomerID int)
    LANGUAGE SQL  
BEGIN 
	START TRANSACTION;
	SELECT Garment, Service, DATE_ADD(date_created, INTERVAL days DAY) as ETA 
    FROM (SELECT OrderDetails.Garment, OrderDetails.Service, OrderID, days FROM OrderDetails
		  LEFT JOIN Garments
		  ON OrderDetails.Garment = Garments.Garment AND OrderDetails.Service = Garments.Service
		  WHERE OrderID IN (SELECT OrderID from Orders WHERE CustomerID = RequestedCustomerID)) as T
	LEFT JOIN Orders
    ON Orders.OrderID = T.OrderID;
	COMMIT;
END$$
DELIMITER ;


-- Using the Database

-- Using the database, we will walk through cycles where users interact with the store and submit washes, 
-- the store owner completes washes and updates their status accordingly
-- Nobody knows SQL and everyone is only provided with the procedures and functions to use. The initial details are filled by us, 
-- the databse designers for the Store Owner

-- Person(hence referred to as Store Owner) starts a laundromat service and populates their services and stations
INSERT INTO garments(garment, service, days, price) values
('shirt', 'machine wash', 1, 5),
('shirt', 'hand wash', 1, 7),
('shirt', 'dry clean', 2, 10),
('tshirt', 'machine wash', 1, 4),
('tshirt', 'hand wash', 1, 6),
('tshirt', 'dry clean', 2, 9),
('undergarments', 'machine wash', 1, 5),
('undergarments', 'hand wash', 1, 7),
('pants', 'machine wash', 1, 6),
('pants', 'hand wash', 1, 8),
('pants', 'dry clean', 2, 11),
('jacket', 'dry clean', 2, 20),
('blanket', 'dry clean', 2, 30),
('dress', 'machine wash', 1, 5),
('dress', 'hand wash', 1, 7),
('dress', 'dry clean', 2, 10);

INSERT INTO stations(service, capacity) values
('machine wash', 20),
('machine wash', 10),
('hand wash', 20),
('hand wash', 10),
('dry clean', 10),
('dry clean', 5);

-- New user, Rahul, wants to know which services are offered
call GetServiceDetails();
-- Rahul submits an order 
SET @RahulOrderId = StartNewOrder(0, 'Rahul');
call SubmitWashPerItem(@RahulOrderId, 'blanket', 'dry clean', 2);
call SubmitWashPerItem(@RahulOrderId, 'shirt', 'hand wash', 3);
call SubmitWashPerItem(@RahulOrderId, 'pants', 'dry clean', 2);
call SubmitWashPerItem(@RahulOrderId, 'tshirt', 'machine wash', 2);
call SubmitWashPerItem(@RahulOrderId, 'undergarments', 'machine wash', 4);

-- New user, Rohan, wants to know which services are offered
call GetServiceDetails();

-- Rohan submits an order
SET @RohanOrderId = StartNewOrder(0, 'Rohan');
call SubmitWashPerItem(@RohanOrderId, 'jacket', 'dry clean', 3);
call SubmitWashPerItem(@RohanOrderId, 'shirt', 'dry clean', 2);
call SubmitWashPerItem(@RohanOrderId, 'pants', 'dry clean', 2);
call SubmitWashPerItem(@RohanOrderId, 'undergarments', 'machine wash', 2);

-- New user, Anjali, wants to know which services are offered
call GetServiceDetails();

-- Anjali submits an order
SET @AnjaliOrderId = StartNewOrder(0, 'Anjali');
call SubmitWashPerItem(@AnjaliOrderId, 'dress', 'dry clean', 1);
call SubmitWashPerItem(@AnjaliOrderId, 'dress', 'hand wash', 1);
call SubmitWashPerItem(@AnjaliOrderId, 'jacket', 'dry clean', 1);
call SubmitWashPerItem(@AnjaliOrderId, 'undergarments', 'machine wash', 2);

-- Anjali wishes to know the total price of her order
call GetPriceOfOrder(@AnjaliOrderId);

-- Rahul wishes to know the status of his order
call GetCustomerStatus(1);

-- Rohan wishes to know the status of his order
call GetCustomerStatus(2);

-- Rohan wishes to know by when he will receive his order
call GetETA(2);

-- Store owner wants to schedule the order he has received
call ShowPending();
call AssignToStation(1,5);
call AssignToStation(3,6);
call AssignToStation(6,6);
call AssignToStation(7,5);
call AssignToStation(8, 5);
call AssignToStation(10, 5);
call AssignToStation(12, 5);
call AssignToStation(2, 4);
call AssignToStation(5, 1);

-- Assuming some of the washes are completed, Store Owner frees up some of his stations
call GetStationDetails();
call FreeStation(1,5);
call FreeStation(4,2);
call FreeStation(5,1);
call FreeStation(5,12);
call FreeStation(6,6);

-- Rohan wishes to know the status of his order
call GetCustomerStatus(2);

-- Store owner wishes to check his earnings
 call GetFinances();
 
 -- Rahul wishes to submit more washes
SET @RahulOrderId = StartNewOrder(1, 'Rahul');
call SubmitWashPerItem(@RahulOrderId, 'jacket', 'dry clean', 2);

-- Store Owner assigns and frees up some more stations;
call ShowPending();
call AssignToStation(14,6);
call AssignToStation(11,4);
call AssignToStation(13,1);

call GetStationDetails();
call FreeStation(5,7);
call FreeStation(6,3);

-- and so on

-- Test Case validations(Execute after the above queries have been executed)
-- Edge Cases have been built into the database itself. The queries to validate them can be found below.

-- If we try to assign more than what a station can handle, it does not permit it
SET @RahulOrderId = StartNewOrder(1, 'Rahul');
call SubmitWashPerItem(@RahulOrderId, 'jacket', 'dry clean', 30);
call ShowPending();
call AssignToStation(15,6);
-- If a station which does not exist is requested, it does not permit it
call AssignToStation(15,20);
-- Foreign key constraint - you always want to have a record of your orders
DELETE FROM OrderDetails;
-- If CustomerID submitted does not exist in our database of customers, the customer is automatically created
SELECT * FROM Customers;
SET @TestOrderID = StartNewOrder(5,'Test Customer');
SELECT * From Customers;
-- If we try to avail a garment-service which is not provided, it does not permit it
call SubmitWashPerItem(@TestOrderID, 'jacket', 'machine wash', 1);

-- DROP DATABASE Laundry;
