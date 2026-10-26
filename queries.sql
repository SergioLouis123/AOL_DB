USE kodes_retail;
GO

--Pre-query preparations
IF COL_LENGTH('dbo.Product', 'UnitPrice') IS NULL
  ALTER TABLE dbo.Product
    ADD UnitPrice DECIMAL(10,2) NOT NULL
      CONSTRAINT DF_Product_UnitPrice DEFAULT (0)
      CONSTRAINT CK_Product_UnitPrice CHECK (UnitPrice >= 0);
GO

WITH LatestPrice AS (
  SELECT  d.StockCode, d.UnitPrice, ROW_NUMBER() OVER (PARTITION BY d.StockCode ORDER BY i.InvoiceDate DESC, d.InvoiceDetailID DESC) AS rn
  FROM dbo.Invoice_Detail AS d
  JOIN dbo.Invoice AS i ON i.InvoiceID = d.InvoiceID
  WHERE d.Quantity > 0 AND d.UnitPrice > 0
)
UPDATE  p
SET     p.UnitPrice = lp.UnitPrice
FROM    dbo.Product AS p
JOIN    LatestPrice AS lp ON lp.StockCode = p.StockCode AND lp.rn = 1
WHERE   p.UnitPrice = 0;
GO

IF COL_LENGTH('dbo.Invoice', 'Status') IS NULL
  ALTER TABLE dbo.Invoice
    ADD Status VARCHAR(20) NOT NULL
      CONSTRAINT DF_Invoice_Status DEFAULT ('Completed')
      CONSTRAINT CK_Invoice_Status CHECK (Status IN ('Completed', 'Cancelled'));
GO

UPDATE dbo.Invoice
SET    Status = 'Cancelled'
WHERE  InvoiceID LIKE 'C%' AND Status <> 'Cancelled';
GO

IF COL_LENGTH('dbo.Invoice', 'Country') IS NULL
  ALTER TABLE dbo.Invoice ADD Country VARCHAR(50) NULL;
GO

UPDATE  i
SET     i.Country = s.Country
FROM    dbo.Invoice AS i
JOIN   (SELECT LTRIM(RTRIM(Invoice)) AS InvoiceID, MAX(NULLIF(LTRIM(RTRIM(Country)), '')) AS Country
FROM   dbo.Staging
GROUP BY LTRIM(RTRIM(Invoice))) AS s
ON s.InvoiceID = i.InvoiceID
WHERE   i.Country IS NULL;
GO

-- Query 1
BEGIN TRY
  BEGIN TRANSACTION;

  DECLARE @PriceChanges TABLE (
    StockCode VARCHAR(50),
    OldPrice  DECIMAL(10,2),
    NewPrice  DECIMAL(10,2)
  );

  UPDATE dbo.Product
  SET UnitPrice = ROUND(UnitPrice * 1.08, 2)
  OUTPUT deleted.StockCode, deleted.UnitPrice, inserted.UnitPrice
  INTO @PriceChanges (StockCode, OldPrice, NewPrice)
  WHERE  UnitPrice > 0 AND  UnitPrice < 5.00;

  SELECT COUNT(*) AS ProductsUpdated FROM @PriceChanges;

  SELECT * FROM @PriceChanges
  ORDER BY StockCode;

  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
GO


-- Query 2
DECLARE @InvoiceID VARCHAR(20) = '489434';

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.Invoice WHERE InvoiceID = @InvoiceID)
      THROW 50001, 'Invoice not found.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Invoice WHERE InvoiceID = @InvoiceID AND Status = 'Cancelled')
      THROW 50002, 'Invoice is already cancelled.', 1;

    UPDATE dbo.Invoice
    SET Status = 'Cancelled'
    WHERE InvoiceID = @InvoiceID AND Status = 'Completed';

    SELECT InvoiceID, InvoiceDate, CustomerID, Status
    FROM dbo.Invoice
    WHERE InvoiceID = @InvoiceID;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


-- Query 3
SELECT  COALESCE(i.Country, 'Unknown') AS Country, CAST(SUM(d.Quantity * d.UnitPrice) AS DECIMAL(18,2)) AS TotalRevenue, COUNT(DISTINCT i.InvoiceID) AS CompletedInvoices
FROM dbo.Invoice AS i
JOIN dbo.Invoice_Detail AS d ON d.InvoiceID = i.InvoiceID
WHERE i.Status = 'Completed' AND d.Quantity > 0 AND d.UnitPrice > 0
GROUP BY COALESCE(i.Country, 'Unknown')
ORDER BY TotalRevenue DESC;
GO


-- Query 4
WITH CustomerSpend AS (
  SELECT c.CustomerID, c.Country, CAST(COALESCE(SUM(d.Quantity * d.UnitPrice), 0) AS DECIMAL(18,2)) AS TotalSpend
  FROM dbo.Customer AS c
  LEFT JOIN dbo.Invoice AS i ON i.CustomerID = c.CustomerID AND i.Status = 'Completed'
  LEFT JOIN dbo.Invoice_Detail AS d ON d.InvoiceID = i.InvoiceID AND d.Quantity > 0 AND d.UnitPrice > 0
  GROUP BY c.CustomerID, c.Country
)
SELECT cs.CustomerID, cs.Country, cs.TotalSpend
FROM CustomerSpend AS cs
WHERE cs.TotalSpend > (SELECT AVG(CAST(TotalSpend AS DECIMAL(18,6)))
FROM CustomerSpend)
ORDER BY cs.TotalSpend DESC;
GO


-- Query 5
SELECT p.StockCode, p.Description, COUNT(DISTINCT c.Country) AS BuyerCountries
FROM dbo.Product AS p
JOIN dbo.Invoice_Detail AS d ON d.StockCode = p.StockCode AND d.Quantity  > 0
JOIN dbo.Invoice AS i ON i.InvoiceID  = d.InvoiceID AND i.Status = 'Completed'
JOIN dbo.Customer AS c ON c.CustomerID = i.CustomerID
WHERE c.Country NOT IN ('Germany', 'Unspecified', 'Unknown') AND p.StockCode NOT IN (
  SELECT dg.StockCode
  FROM dbo.Invoice_Detail AS dg
  JOIN dbo.Invoice  AS ig ON ig.InvoiceID = dg.InvoiceID AND ig.Status = 'Completed'
  JOIN dbo.Customer AS cg ON cg.CustomerID = ig.CustomerID
  WHERE dg.Quantity > 0 AND cg.Country  = 'Germany')
GROUP BY p.StockCode, p.Description
HAVING  COUNT(DISTINCT c.Country) >= 2
ORDER BY BuyerCountries DESC, p.StockCode;
GO
