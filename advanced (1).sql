USE kodes_retail;
GO

IF COL_LENGTH('dbo.Product', 'StockQty') IS NULL
BEGIN
    ALTER TABLE dbo.Product
    ADD StockQty INT NOT NULL
        CONSTRAINT DF_Product_StockQty DEFAULT (0);
END
GO

CREATE OR ALTER TRIGGER dbo.trg_Invoice_Detail_UpdateInventory
ON dbo.Invoice_Detail
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE p
    SET p.StockQty = p.StockQty - i.TotalQty
    FROM dbo.Product AS p
    INNER JOIN (
        SELECT StockCode, SUM(Quantity) AS TotalQty
        FROM inserted
        GROUP BY StockCode
    ) AS i
        ON i.StockCode = p.StockCode;
END;
GO

CREATE OR ALTER PROCEDURE dbo.GetCustomerInvoiceHistory
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        i.InvoiceID,
        i.InvoiceDate,
        ISNULL(SUM(d.Quantity * d.UnitPrice), 0) AS TotalValue
    FROM dbo.Invoice AS i
    LEFT JOIN dbo.Invoice_Detail AS d
        ON d.InvoiceID = i.InvoiceID
    WHERE i.CustomerID = @CustomerID
    GROUP BY i.InvoiceID, i.InvoiceDate
    ORDER BY i.InvoiceDate DESC;
END;
GO
