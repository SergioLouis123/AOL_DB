USE kodes_retail;
GO

DROP TABLE IF EXISTS dbo.Invoice_Detail;
DROP TABLE IF EXISTS dbo.Invoice;
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.Customer;
GO

USE kodes_retail;
GO

CREATE TABLE dbo.Customer (
    CustomerID INT NOT NULL,
    Country VARCHAR(50) NOT NULL
        CONSTRAINT DF_Customer_Country DEFAULT ('Unknown'),

    CONSTRAINT PK_Customer
        PRIMARY KEY (CustomerID)
);
GO

CREATE TABLE dbo.Product (
    StockCode VARCHAR(50) NOT NULL,
    Description VARCHAR(255) NULL,

    CONSTRAINT PK_Product
        PRIMARY KEY (StockCode)
);
GO

CREATE TABLE dbo.Invoice (
    InvoiceID VARCHAR(20) NOT NULL,
    InvoiceDate DATETIME2(0) NOT NULL,
    CustomerID INT NULL,

    CONSTRAINT PK_Invoice
        PRIMARY KEY (InvoiceID),

    CONSTRAINT FK_Invoice_Customer
        FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customer(CustomerID)
        ON DELETE NO ACTION
        ON UPDATE CASCADE
);
GO

CREATE TABLE dbo.Invoice_Detail (
    InvoiceDetailID BIGINT IDENTITY(1,1) NOT NULL,
    InvoiceID VARCHAR(20) NOT NULL,
    StockCode VARCHAR(50) NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,

    CONSTRAINT PK_Invoice_Detail
        PRIMARY KEY (InvoiceDetailID),

    CONSTRAINT FK_Invoice_Detail_Invoice
        FOREIGN KEY (InvoiceID)
        REFERENCES dbo.Invoice(InvoiceID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT FK_Invoice_Detail_Product
        FOREIGN KEY (StockCode)
        REFERENCES dbo.Product(StockCode)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,

    CONSTRAINT CK_Invoice_Detail_Quantity
        CHECK (Quantity <> 0)
);
GO

SELECT
    TRY_CONVERT(INT, LTRIM(RTRIM(CustomerID))) AS CustomerID,
    COUNT(DISTINCT NULLIF(LTRIM(RTRIM(Country)), ''))
        AS CountryVariants
FROM dbo.Staging
WHERE TRY_CONVERT(INT, LTRIM(RTRIM(CustomerID))) IS NOT NULL
GROUP BY TRY_CONVERT(INT, LTRIM(RTRIM(CustomerID)))
HAVING COUNT(DISTINCT NULLIF(LTRIM(RTRIM(Country)), '')) > 1;
GO

INSERT INTO dbo.Customer (CustomerID, Country)
SELECT
    TRY_CONVERT(INT, LTRIM(RTRIM(CustomerID))),
    COALESCE(
        MAX(NULLIF(LTRIM(RTRIM(Country)), '')),
        'Unknown'
    )
FROM dbo.Staging
WHERE TRY_CONVERT(INT, LTRIM(RTRIM(CustomerID))) IS NOT NULL
GROUP BY TRY_CONVERT(INT, LTRIM(RTRIM(CustomerID)));
GO

SELECT
    LTRIM(RTRIM(StockCode)) AS StockCode,
    COUNT(DISTINCT NULLIF(LTRIM(RTRIM(Description)), ''))
        AS DescriptionVariants
FROM dbo.Staging
WHERE NULLIF(LTRIM(RTRIM(StockCode)), '') IS NOT NULL
GROUP BY LTRIM(RTRIM(StockCode))
HAVING COUNT(DISTINCT NULLIF(LTRIM(RTRIM(Description)), '')) > 1;
GO

INSERT INTO dbo.Product (StockCode, Description)
SELECT
    LTRIM(RTRIM(StockCode)),
    MAX(NULLIF(LTRIM(RTRIM(Description)), ''))
FROM dbo.Staging
WHERE NULLIF(LTRIM(RTRIM(StockCode)), '') IS NOT NULL
GROUP BY LTRIM(RTRIM(StockCode));
GO

WITH InvoiceSource AS (
    SELECT
        LTRIM(RTRIM(Invoice)) AS InvoiceID,
        TRY_CONVERT(
            DATETIME2(0),
            LTRIM(RTRIM(InvoiceDate)),
            101
        ) AS InvoiceDate,
        TRY_CONVERT(
            INT,
            NULLIF(LTRIM(RTRIM(CustomerID)), '')
        ) AS CustomerID
    FROM dbo.Staging
    WHERE NULLIF(LTRIM(RTRIM(Invoice)), '') IS NOT NULL
)
SELECT
    InvoiceID,
    COUNT(DISTINCT InvoiceDate) AS DistinctDates,
    COUNT(DISTINCT CustomerID) AS DistinctCustomerIDs
FROM InvoiceSource
GROUP BY InvoiceID
HAVING
    COUNT(DISTINCT InvoiceDate) > 1
    OR COUNT(DISTINCT CustomerID) > 1;
GO

WITH InvoiceSource AS (
    SELECT
        LTRIM(RTRIM(Invoice)) AS InvoiceID,
        TRY_CONVERT(
            DATETIME2(0),
            LTRIM(RTRIM(InvoiceDate)),
            101
        ) AS InvoiceDate,
        TRY_CONVERT(
            INT,
            NULLIF(LTRIM(RTRIM(CustomerID)), '')
        ) AS CustomerID
    FROM dbo.Staging
    WHERE NULLIF(LTRIM(RTRIM(Invoice)), '') IS NOT NULL
),
InvoiceGrouped AS (
    SELECT
        InvoiceID,
        MIN(InvoiceDate) AS InvoiceDate,
        MAX(CustomerID) AS CustomerID
    FROM InvoiceSource
    GROUP BY InvoiceID
)
INSERT INTO dbo.Invoice (InvoiceID, InvoiceDate, CustomerID)
SELECT
    ig.InvoiceID,
    ig.InvoiceDate,
    c.CustomerID
FROM InvoiceGrouped AS ig
LEFT JOIN dbo.Customer AS c
    ON c.CustomerID = ig.CustomerID
WHERE ig.InvoiceDate IS NOT NULL;
GO


INSERT INTO dbo.Invoice_Detail
    (InvoiceID, StockCode, Quantity, UnitPrice)
SELECT
    LTRIM(RTRIM(s.Invoice)),
    LTRIM(RTRIM(s.StockCode)),
    TRY_CONVERT(INT, LTRIM(RTRIM(s.Quantity))),
    TRY_CONVERT(DECIMAL(10,2), LTRIM(RTRIM(s.Price)))
FROM dbo.Staging AS s
INNER JOIN dbo.Invoice AS i
    ON i.InvoiceID = LTRIM(RTRIM(s.Invoice))
INNER JOIN dbo.Product AS p
    ON p.StockCode = LTRIM(RTRIM(s.StockCode))
WHERE
    NULLIF(LTRIM(RTRIM(s.Invoice)), '') IS NOT NULL
    AND NULLIF(LTRIM(RTRIM(s.StockCode)), '') IS NOT NULL
    AND TRY_CONVERT(INT, LTRIM(RTRIM(s.Quantity))) IS NOT NULL
    AND TRY_CONVERT(INT, LTRIM(RTRIM(s.Quantity))) <> 0
    AND TRY_CONVERT(
        DECIMAL(10,2),
        LTRIM(RTRIM(s.Price))
    ) IS NOT NULL;
GO

SELECT 'Staging' AS TableName, COUNT_BIG(*) AS TotalRows
FROM dbo.Staging

UNION ALL

SELECT 'Customer', COUNT_BIG(*)
FROM dbo.Customer

UNION ALL

SELECT 'Product', COUNT_BIG(*)
FROM dbo.Product

UNION ALL

SELECT 'Invoice', COUNT_BIG(*)
FROM dbo.Invoice

UNION ALL

SELECT 'Invoice_Detail', COUNT_BIG(*)
FROM dbo.Invoice_Detail;
GO

SELECT
    COUNT_BIG(*) AS InvalidInvoiceDates
FROM dbo.Staging
WHERE TRY_CONVERT(
    DATETIME2(0),
    LTRIM(RTRIM(InvoiceDate)),
    101
) IS NULL;
GO

SELECT
    COUNT_BIG(*) AS InvalidCustomerIDs
FROM dbo.Staging
WHERE NULLIF(LTRIM(RTRIM(CustomerID)), '') IS NOT NULL
  AND TRY_CONVERT(INT, LTRIM(RTRIM(CustomerID))) IS NULL;
GO

SELECT
    COUNT_BIG(*) AS InvalidPrices
FROM dbo.Staging
WHERE TRY_CONVERT(
    DECIMAL(10,2),
    LTRIM(RTRIM(Price))
) IS NULL;
GO

SELECT
    COUNT_BIG(*) AS InvalidQuantities
FROM dbo.Staging
WHERE TRY_CONVERT(INT, LTRIM(RTRIM(Quantity))) IS NULL;
GO


SELECT COUNT_BIG(*) AS RowsNotEligibleForInvoiceDetail
FROM dbo.Staging AS s
WHERE
    NULLIF(LTRIM(RTRIM(s.Invoice)), '') IS NULL
    OR NULLIF(LTRIM(RTRIM(s.StockCode)), '') IS NULL
    OR TRY_CONVERT(
        DATETIME2(0),
        LTRIM(RTRIM(s.InvoiceDate)),
        101
    ) IS NULL
    OR TRY_CONVERT(INT, LTRIM(RTRIM(s.Quantity))) IS NULL
    OR TRY_CONVERT(INT, LTRIM(RTRIM(s.Quantity))) = 0
    OR TRY_CONVERT(
        DECIMAL(10,2),
        LTRIM(RTRIM(s.Price))
    ) IS NULL
    OR NOT EXISTS (
        SELECT 1
        FROM dbo.Invoice AS i
        WHERE i.InvoiceID = LTRIM(RTRIM(s.Invoice))
    )
    OR NOT EXISTS (
        SELECT 1
        FROM dbo.Product AS p
        WHERE p.StockCode = LTRIM(RTRIM(s.StockCode))
    );
GO

SELECT d.*
FROM dbo.Invoice_Detail AS d
LEFT JOIN dbo.Invoice AS i
    ON i.InvoiceID = d.InvoiceID
WHERE i.InvoiceID IS NULL;

SELECT d.*
FROM dbo.Invoice_Detail AS d
LEFT JOIN dbo.Product AS p
    ON p.StockCode = d.StockCode
WHERE p.StockCode IS NULL;
GO

SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME() AS CurrentDatabase,
    @@SPID AS SessionID;
