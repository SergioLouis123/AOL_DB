import csv
import pyodbc

CSV_FILE = r"D:\AOL DB\online_retail_data(in).csv"
SERVER = r"Meira\SQLEXPRESS"
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

recovered = 0
batch = []
batch_size = 1000

try:
    with open(
        CSV_FILE, newline="", encoding="utf-8-sig"
    ) as f:
        reader = csv.reader(f)
        next(reader, None)

        for row in reader:
            if len(row) != 1:
                continue

            # Parse the entire line again to recover its 8 fields.
            parsed = next(csv.reader([row[0]]))

            if len(parsed) != 8:
                continue

            batch.append(parsed)

            if len(batch) >= batch_size:
                cursor.executemany(sql, batch)
                conn.commit()
                recovered += len(batch)
                print("Recovered:", recovered)
                batch.clear()

        if batch:
            cursor.executemany(sql, batch)
            conn.commit()
            recovered += len(batch)

    print("\nRecovery completed!")
    print("Rows recovered:", recovered)

except Exception as error:
    conn.rollback()
    print("\nRecovery error:", error)
    print("Only the current uncommitted batch was rolled back.")

finally:
    cursor.close()
    conn.close()
