import psycopg2
import random
from datetime import datetime, timedelta, timezone

# -----------------------------
# PostgreSQL connection
# -----------------------------
conn = psycopg2.connect(
    dbname="smart_grid",
    user="postgres",
    password="Umutoni@999",
    host="localhost",
    port="5432"
)
cursor = conn.cursor()

# -----------------------------
# Configuration
# -----------------------------
NUM_METERS = 1050
INTERVAL_MINUTES = 5
DAYS = 14
BATCH_SIZE = 500000  # larger batch for faster inserts
PRINT_SAMPLE = 5

start_time = datetime.now(timezone.utc) - timedelta(days=DAYS)
end_time = datetime.now(timezone.utc)

batch = []
current_time = start_time
printed_rows = 0

# -----------------------------
# Data generation loop
# -----------------------------
while current_time <= end_time:
    hour = current_time.hour

    for meter_id in range(1, NUM_METERS + 1):
        # Realistic daily usage pattern
        if 6 <= hour <= 9 or 18 <= hour <= 21:
            power = random.uniform(2.5, 5.0)  # peak hours
        elif 10 <= hour <= 17:
            power = random.uniform(1.5, 3.0)  # normal hours
        else:
            power = random.uniform(0.5, 1.5)  # night hours

        voltage = random.gauss(230, 2)
        current = power / voltage * 10
        frequency = 50 + random.uniform(-0.1, 0.1)
        energy = power * (INTERVAL_MINUTES / 60)

        batch.append((
            f"{meter_id:010d}",
            current_time,
            power,
            voltage,
            current,
            frequency,
            energy
        ))

        # Print a few sample rows
        if printed_rows < PRINT_SAMPLE:
            print(batch[-1])
            printed_rows += 1

    # Insert in batches
    if len(batch) >= BATCH_SIZE:
        cursor.executemany("""
            INSERT INTO energy_readings
            (meter_id, timestamp, power, voltage, current, frequency, energy)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, batch)
        conn.commit()
        batch.clear()
        print(f"Inserted batch at {current_time}")

    current_time += timedelta(minutes=INTERVAL_MINUTES)

# Insert remaining rows
if batch:
    cursor.executemany("""
        INSERT INTO energy_readings
        (meter_id, timestamp, power, voltage, current, frequency, energy)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, batch)
    conn.commit()
    batch.clear()

print("Historical data generation complete (~4.2M rows)")

# Close connection
cursor.close()
conn.close()
