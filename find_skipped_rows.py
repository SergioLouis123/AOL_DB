# import csv

# CSV_FILE = r"D:\AOL DB\online_retail_data(in).csv"
# OUTPUT_FILE = r"D:\AOL DB\skipped_rows.csv"

# total = 0
# skipped = 0

# with open(CSV_FILE, newline="", encoding="utf-8-sig") as source, \
#      open(OUTPUT_FILE, "w", newline="", encoding="utf-8-sig") as output:

#     reader = csv.reader(source)
#     writer = csv.writer(output)

#     header = next(reader, None)
#     writer.writerow(["OriginalLineNumber", "ColumnCount", "RawRow"])
#     # Store each skipped row's original line number and contents.

#     for line_number, row in enumerate(reader, start=2):
#         total += 1

#         if len(row) != 8:
#             skipped += 1
#             writer.writerow([line_number, len(row), repr(row)])

# print("Total data rows:", total)
# print("Skipped rows found:", skipped)
# print("Saved to:", OUTPUT_FILE)

import csv

file_path = r"D:\AOL DB\online_retail_data(in).csv"

with open(file_path, "r", encoding="utf-8-sig", newline="") as f:
    reader = csv.reader(f)
    header = next(reader)

    total = 0
    last_rows = []

    for row in reader:
        total += 1
        last_rows.append(row)

        if len(last_rows) > 5:
            last_rows.pop(0)

print("Total data rows:", total)
print("Header:", header)
print("\nLast 5 records:")

for row in last_rows:
    print(row)