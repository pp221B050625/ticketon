create database tiketon
use tiketon

CREATE TABLE CUSTOMERS(
customer_id int identity(1,1) primary key,
name varchar(50) not null,
email varchar(50) not null  
)

CREATE TABLE ORDER_ITEM(
order_item_id int identity(1,1),
order_id int,
customer_id int,
status varchar(30) not null,
amount int,
event_id int
)
CREATE TABLE ORDERS(
order_id int primary key,
customer_id int not null,
total float not null,
date date not null
)
CREATE TABLE VENUES(
venue_id int identity(1,1) primary key,
name varchar(50) not null,
address varchar(100) not null
)
CREATE TABLE TICKETS(
venue_id int,
event_id int,
price float not null,
seat_amount int not null
)
CREATE TABLE EVENTS(
event_id int primary key,
name varchar(100) not null,
venue_id int not null,
date date not null,
price int not null,
seat_amount int not null
)
drop table ORDER_ITEM
CREATE TABLE BONUSES(
customer_id int primary key,
bonus_amount float,
date date
)
INSERT INTO BONUSES VALUES (2,0,'2022-08-01'),(3,0,'2023-02-21'),(6,0,'2023-04-30'),(9,0,'2023-05-06')

--NUMBER 1
CREATE OR ALTER PROCEDURE ORDERING @CUSTOMER_ID INT, @ADULT INT, @STUDENT INT, @KID INT, @EVENT_ID INT
AS BEGIN 
DECLARE @NEW_ROW INT
IF (SELECT MAX(ORDER_ID) FROM ORDER_ITEM) IS NULL BEGIN 
SET @NEW_ROW = 1 END
ELSE BEGIN
SET @NEW_ROW = (SELECT MAX(ORDER_ID) FROM ORDER_ITEM)+1 END
IF (SELECT SEAT_AMOUNT FROM EVENTS WHERE EVENT_ID = @EVENT_ID) < (@ADULT+@STUDENT+@KID) BEGIN 
PRINT('THERE IS NOT ENOUGH SEATS FROM THIS EVENT! PLEASE TRY OTHER ONES.') END
ELSE BEGIN
IF @ADULT > 0 BEGIN
INSERT INTO ORDER_ITEM VALUES(@NEW_ROW,'adult',@ADULT,@EVENT_ID) END
IF @STUDENT >0 BEGIN
INSERT INTO ORDER_ITEM VALUES(@NEW_ROW,'student',@STUDENT,@EVENT_ID) END
IF @KID >0 BEGIN
INSERT INTO ORDER_ITEM VALUES(@NEW_ROW,'kid',@KID,@EVENT_ID) END
DECLARE @PRICE INT
SET @PRICE = (SELECT PRICE FROM EVENTS WHERE EVENT_ID = @EVENT_ID)
INSERT INTO ORDERS VALUES (@NEW_ROW,@CUSTOMER_ID,@PRICE*(@ADULT+@STUDENT*0.8+@KID*0.5),GETDATE())
UPDATE EVENTS SET SEAT_AMOUNT = SEAT_AMOUNT - (@ADULT+@STUDENT+@KID) WHERE EVENT_ID = @EVENT_ID
END END
EXEC ORDERING @CUSTOMER_ID =2, @ADULT = 2, @STUDENT =1, @KID =3, @EVENT_ID = 4

--NUMBER 2
CREATE OR ALTER TRIGGER BONUS ON ORDERS AFTER INSERT,UPDATE AS BEGIN 
DECLARE @TOTAL INT,@CUSTOMER_ID INT
SET @TOTAL = (SELECT TOTAL FROM INSERTED)
SET @CUSTOMER_ID = (SELECT CUSTOMER_ID FROM INSERTED)
IF DATEDIFF(DAY,GETDATE(),(SELECT DATE FROM BONUSES WHERE CUSTOMER_ID = @CUSTOMER_ID)) > 364 BEGIN 
DELETE FROM BONUSES WHERE CUSTOMER_ID = @CUSTOMER_ID END
ELSE BEGIN
IF @CUSTOMER_ID IN (SELECT CUSTOMER_ID FROM BONUSES) BEGIN 
UPDATE BONUSES SET bonus_amount = bonus_amount + @TOTAL *0.05 WHERE CUSTOMER_ID = @CUSTOMER_ID
END END END

CREATE PROCEDURE BONUS_SPENDING @CUSTOMER_ID int, @ORDER_ID INT
AS BEGIN 
IF (SELECT BONUS_AMOUNT FROM BONUSES WHERE CUSTOMER_ID = @CUSTOMER_ID) < 20000 BEGIN PRINT('NOT ENOUGH BONUSES!') END
ELSE BEGIN 
IF (SELECT TOTAL FROM ORDERS WHERE ORDER_ID = @ORDER_ID) > (SELECT BONUS_AMOUNT FROM BONUSES WHERE CUSTOMER_ID = @CUSTOMER_ID)
BEGIN PRINT('NOT ENOUGH BONUSES FOR EXCHANGE!') END
ELSE BEGIN 
UPDATE BONUSES SET bonus_amount = bonus_amount - (SELECT TOTAL FROM ORDERS WHERE ORDER_ID = @ORDER_ID) WHERE customer_id = @CUSTOMER_ID
UPDATE ORDERS SET TOTAL = 0 WHERE ORDER_ID = @ORDER_ID
END END END
EXEC BONUS_SPENDING @CUSTOMER_ID = 2, @ORDER_ID =1

--NUMBER 3
CREATE PROCEDURE DELETE_EVENT @EVENT_ID INT
AS
BEGIN DELETE FROM EVENTS
 WHERE event_id = @EVENT_ID
END;
CREATE TRIGGER DELETE_AFTER_EVENT_REFUND ON EVENTS
INSTEAD OF DELETE AS
BEGIN
 DECLARE @COUNTER INT
 SET @COUNTER = (SELECT COUNT(total) FROM ORDERS     WHERE customer_id IN (SELECT distinct O.customer_id
      FROM ORDERS O      INNER JOIN ORDER_ITEM OI
      ON O.order_id = OI.order_id      WHERE OI.event_id = (SELECT event_id FROM DELETED)))
 WHILE (@COUNTER != 0)
 BEGIN  DECLARE @CUST_TOP INT
  SET @CUST_TOP = (SELECT DISTINCT TOP 1 O.customer_id       FROM ORDERS O
       LEFT JOIN ORDER_ITEM OI       ON O.order_id = OI.order_id
       WHERE OI.event_id = (SELECT event_id FROM DELETED))
  DECLARE @ORDER_TOP INT  SET @ORDER_TOP = (SELECT DISTINCT TOP 1 O.order_id
       FROM ORDERS O       LEFT JOIN ORDER_ITEM OI
       ON O.order_id = OI.order_id       WHERE OI.event_id = (SELECT event_id FROM DELETED))
  UPDATE CUSTOMERS  SET  wallet += (SELECT TOP 1 total FROM ORDERS
      WHERE order_id IN        (SELECT distinct O.customer_id
       FROM ORDERS O       INNER JOIN ORDER_ITEM OI
       ON O.order_id = OI.order_id       WHERE OI.event_id = 
        (SELECT event_id FROM DELETED)))  WHERE customer_id = @CUST_TOP
  DELETE FROM ORDER_ITEM
  WHERE order_id = @ORDER_TOP  
  DELETE FROM ORDERS  WHERE customer_id = @CUST_TOP
  SET @COUNTER = @COUNTER - 1
 END
 DELETE FROM EVENTS WHERE event_id = (SELECT event_id FROM DELETED)
END;
EXEC DELETE_EVENT @EVENT_ID = 8

--NUMBER 4
CREATE TRIGGER add_event ON EVENTS
INSTEAD OF INSERT
AS
BEGIN    IF EXISTS(SELECT 1 FROM EVENTS WHERE venue_id = (SELECT venue_id FROM inserted) AND date = (SELECT date FROM inserted))
    BEGIN        PRINT 'This venue is taken at this date'
    END    ELSE
    BEGIN        INSERT INTO EVENTS(name, venue_id, date, price, seat_amount)
        SELECT name, venue_id, date, price, seat_amount        FROM inserted
    END
END
drop trigger add_event
select * from EVENTS
--NUMBER 5
CREATE TRIGGER add_venue ON VENUES
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @name VARCHAR(50), @address VARCHAR(100)    SELECT @name = TRIM(name), @address = TRIM(address) FROM inserted
        IF EXISTS(SELECT 1 FROM VENUES WHERE name = @name AND address = @address)
    BEGIN        PRINT 'Venue already inserted'
    END    ELSE
    BEGIN        INSERT INTO VENUES(name, address)
        SELECT @name, @address    END
END

--NUMBER 6
create or alter procedure new_customer
(@customer_name varchar(30), @email varchar(40), @wallet int = null) as 
begin 
  insert into CUSTOMERS
  values(@customer_name, @email, @wallet)
end;

create or alter procedure update_wallet(@cust_id int, @plus int) as
begin 
  if (select wallet from CUSTOMERS where customer_id=@cust_id) is null
    update CUSTOMERS
    set wallet = 0
    WHERE customer_id=@cust_id
  update CUSTOMERS
  set wallet = wallet + @plus
  where customer_id=@cust_id
end;

create or alter trigger user_verification on customers
after insert 
as
begin
  declare @name varchar(30)=(select name from inserted);
  declare @email varchar(40)=(select email from inserted);
  if charindex(' ',@name) = 0
      throw 51000, 'Отсутствует имя или фамилия',1;
  if CHARINDEX('@', @email) = 0 or charindex('.',@email,charindex('@',@email)) = 0
    throw 51000, 'Проверьте почту на корректность',1;
end;

--NUMBER 7
CREATE OR ALTER PROCEDURE new_event
( @event_type varchar(100), @name varchar(30), @venue_id int, @date date, @price float, @seat_amount int, @beginning time, @ends time)
AS
BEGIN 
  DECLARE @event_id int = CASE
    WHEN @event_type = 'Концерт' THEN 201
    WHEN @event_type = 'Кино' THEN 301
    WHEN @event_type = 'Спорт' THEN 101
    WHEN @event_type = 'Театр' THEN 401
    WHEN @event_type = 'Разное' THEN 501
  END;
  while(select event_id from EVENTS where event_id = @event_id) is not null
    begin
      set @event_id = @event_id + 1
    end;
  IF EXISTS (
    SELECT 1 FROM EVENTS
    WHERE venue_id = @venue_id
      AND date = @date
      AND ((@beginning BETWEEN beginning AND ends) OR (@ends BETWEEN beginning AND ends))
  )
  BEGIN
    RAISERROR('Это время пересекается с другим событием', 16, 1);
    RETURN;
  END;

  INSERT INTO EVENTS (event_id, name, venue_id, date, price, seat_amount, beginning, ends)
  VALUES (@event_id, @name, @venue_id, @date, @price, @seat_amount, @beginning, @ends);
END;