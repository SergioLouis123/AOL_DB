
import csv
from collections import Counter

file_path = r"D:\AOL DB\online_retail_data(in).csv"

columns = [
    "Invoice", "StockCode", "Description", "Quantity",
    "InvoiceDate", "Price", "CustomerID", "Country"
]

counts = Counter()
skipped_rows = 0

with open(file_path, "r", encoding="utf-8-sig", newline="") as file:
    reader = csv.reader(file)

    header = next(reader)
    header = [name.strip() for name in header]

    for row in reader:
        if len(row) == 1:
            try:
                row = next(csv.reader([row[0]]))
            except csv.Error:
                skipped_rows += 1
                continue

        if len(row) != len(columns):
            skipped_rows += 1
            continue

        counts[tuple(row)] += 1

duplicate_groups = sum(
    1 for occurrences in counts.values() if occurrences > 1
)

rows_in_groups = sum(
    occurrences for occurrences in counts.values() if occurrences > 1
)

extra_copies = sum(
    occurrences - 1
    for occurrences in counts.values()
    if occurrences > 1
)

print("Exact duplicate groups:", duplicate_groups)
print("Rows in duplicate groups:", rows_in_groups)
print("Extra duplicate copies:", extra_copies)
print("Rows skipped due to invalid column count:", skipped_rows)

print("\nTop 30 repeated records:")
repeated = [
    (record, occurrences)
    for record, occurrences in counts.items()
    if occurrences > 1
]
repeated.sort(key=lambda item: item[1], reverse=True)

for record, occurrences in repeated[:30]:
    print(*record, occurrences, sep=" | ")
