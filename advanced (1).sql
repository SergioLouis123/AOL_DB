USE kodes_retail;
GO

/*
    Phase 4 - Advanced Features & Automation (SQL Server / T-SQL)

    Catatan:
    - Product belum punya kolom stok, jadi ditambah StockQty (inventory level).
    - Retur di dataset ditandai Quantity negatif (Invoice berawalan 'C'),
      jadi satu rumus berlaku untuk dua kasus:
        sale   -> Quantity positif -> stok berkurang
        return -> Quantity negatif -> stok bertambah
*/

-- 1. Tambah kolom inventory ke Product (aman dijalankan ulang)
IF COL_LENGTH('dbo.Product', 'StockQty') IS NULL
BEGIN
    ALTER TABLE dbo.Product
    ADD StockQty INT NOT NULL
        CONSTRAINT DF_Product_StockQty DEFAULT (0);
END
GO

-- 2. Trigger: update stok otomatis tiap ada transaksi baru
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

-- 3. Stored procedure: riwayat invoice per customer
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
