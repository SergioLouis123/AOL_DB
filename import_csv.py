
import csv
import pyodbc

CSV_FILE = r"D:\AOL DB\online_retail_data(in).csv"
SERVER = "localhost"
DRIVER = "ODBC Driver 18 for SQL Server"

conn = pyodbc.connect(
    f"DRIVER={{{DRIVER}}};"
    f"SERVER={SERVER};"
    "DATABASE=kodes_retail;"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)

cursor = conn.cursor()
cursor.fast_executemany = True

sql = """
INSERT INTO dbo.Staging
(Invoice, StockCode, Description, Quantity,
 InvoiceDate, Price, CustomerID, Country)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
"""

total = 0
skipped = 0
batch = []
batch_size = 50000

try:
    with open(
        CSV_FILE,
        newline="",
        encoding="utf-8-sig",
        errors="replace"
    ) as f:

        reader = csv.reader(f)
        next(reader, None)  # Skip header

        for line_number, row in enumerate(reader, start=2):
            if len(row) != 8:
                skipped += 1
                print(
                    f"Skipped line {line_number}: "
                    f"expected 8 columns, got {len(row)}"
                )
                continue

            # Convert empty CSV fields to empty strings.
            # Keep all values as text for staging.
            batch.append(row)

            if len(batch) >= batch_size:
                cursor.executemany(sql, batch)
                conn.commit()

                total += len(batch)
                print(total, "rows loaded...")
                batch.clear()

        if batch:
            cursor.executemany(sql, batch)
            conn.commit()
            total += len(batch)

    print("\nImport completed!")
    print("Total rows loaded:", total)
    print("Rows skipped:", skipped)

except Exception as error:
    conn.rollback()
    print("\nImport error:", error)
    print("The current uncommitted batch was rolled back.")

finally:
    cursor.close()
    conn.close()
