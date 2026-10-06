import pandas as pd
import mysql.connector

# Connect to MySQL
connection = mysql.connector.connect(
    host="localhost",
    port=3306,
    user="root",
    password="Vanshika1111",
    database="retail_analytics"
)

query = """
SELECT
    Invoice,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    Price,
    CustomerID,
    Country,
    Revenue
FROM retail_clean
"""

output_file = "data/cleaned/retail_clean.csv"

# Read and write in chunks so we don't load everything into memory at once
first_chunk = True

for chunk in pd.read_sql(
    query,
    connection,
    chunksize=50000
):
    chunk.to_csv(
        output_file,
        mode="w" if first_chunk else "a",
        index=False,
        header=first_chunk
    )

    first_chunk = False

    print(f"Exported {len(chunk)} rows")

connection.close()

print("Export complete.")

