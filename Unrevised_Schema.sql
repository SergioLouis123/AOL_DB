CREATE DATABASE kodes_retail;
GO

USE kodes_retail;
GO

DROP TABLE IF EXISTS dbo.Invoice_Detail;
DROP TABLE IF EXISTS dbo.Invoice;
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.Customer;
GO

USE kodes_retail;
GO

CREATE TABLE Customer (
    CustomerID INT NOT NULL,
    Country VARCHAR(50) NOT NULL DEFAULT 'Secret',
    PRIMARY KEY (CustomerID)
);

CREATE TABLE Product (
    StockCode VARCHAR(20) NOT NULL,
    Description VARCHAR(255) NULL,
    PRIMARY KEY (StockCode)
);
 
CREATE TABLE Invoice (
    InvoiceID VARCHAR(10) NOT NULL,
    InvoiceDate DATETIME NOT NULL,
    CustomerID INT NULL,
    PRIMARY KEY (InvoiceID),
    FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
        ON DELETE NO ACTION    
        ON UPDATE CASCADE
);
 
CREATE TABLE Invoice_Detail (
    InvoiceID VARCHAR(10) NOT NULL,
    StockCode VARCHAR(20) NOT NULL,
    Quantity  INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (InvoiceID, StockCode),
    FOREIGN KEY (InvoiceID) REFERENCES Invoice(InvoiceID)
        ON DELETE CASCADE        
        ON UPDATE CASCADE,
    FOREIGN KEY (StockCode) REFERENCES Product(StockCode)
        ON DELETE NO ACTION      
        ON UPDATE CASCADE,
    CHECK (Quantity <> 0),       
    CHECK (UnitPrice >= 0)
);
GO

CREATE TABLE Staging (
    Invoice     VARCHAR(20),
    StockCode   VARCHAR(50),
    Description VARCHAR(255),
    Quantity    VARCHAR(20),
    InvoiceDate VARCHAR(50),
    Price       VARCHAR(20),
    CustomerID  VARCHAR(20),
    Country     VARCHAR(50)
);
GO
