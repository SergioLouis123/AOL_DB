
import csv

FILE = r"D:\AOL DB\online_retail_data(in).csv"

one_column = 0
recoverable = 0
unrecoverable = 0
examples = []

with open(FILE, newline="", encoding="utf-8-sig") as f:
    reader = csv.reader(f)
    next(reader, None)

    for row in reader:
        if len(row) == 1:
            one_column += 1

            try:
                recovered = next(csv.reader([row[0]]))

                if len(recovered) == 8:
                    recoverable += 1
                else:
                    unrecoverable += 1
                    if len(examples) < 5:
                        examples.append((len(recovered), row[0]))

            except csv.Error:
                unrecoverable += 1
                if len(examples) < 5:
                    examples.append(("CSV error", row[0]))

print("Rows needing recovery:", one_column)
print("Recoverable rows:", recoverable)
print("Unrecoverable rows:", unrecoverable)

for count, content in examples:
    print("\nProblem:", count)
    print("Content:", content)
