import json
import random
import time
from datetime import datetime, timedelta, timezone
from paho.mqtt import client as mqtt_client

# ---------------- SETTINGS ----------------
BROKER = "localhost"
TOPIC_TEMPLATE = "energy/meters/{}"
NUM_METERS = 500
INTERVAL_SECONDS = 5 * 60   # 5 minutes
SIMULATION_SPEED = 60       # accelerate simulation
# ------------------------------------------

# Rwanda timezone (UTC+2)
RWANDA_TZ = timezone(timedelta(hours=2))

client = mqtt_client.Client()
client.connect(BROKER)

def generate_meter_data(meter_id, timestamp):
    hour = timestamp.hour

    # Realistic consumption pattern
    if 6 <= hour <= 9 or 18 <= hour <= 21:
        base_power = random.uniform(2.5, 5.0)       # morning/evening high usage
    elif 10 <= hour <= 17:
        base_power = random.uniform(1.5, 3.0)       # daytime medium
    else:
        base_power = random.uniform(0.5, 1.5)       # night low

    voltage = random.gauss(230, 2)
    current = base_power / voltage * 10
    frequency = 50 + random.uniform(-0.1, 0.1)
    energy = base_power * (INTERVAL_SECONDS / 3600)

    return {
        "meter_id": f"{meter_id:010d}",
        "timestamp": timestamp.isoformat(),
        "power": round(base_power, 2),
        "voltage": round(voltage, 2),
        "current": round(current, 2),
        "frequency": round(frequency, 2),
        "energy": round(energy, 4)
    }

# ---- Start exactly 1 hour before now in Rwanda ----
now_rw = datetime.now(RWANDA_TZ)
current_time = now_rw - timedelta(hours=1)

print(f"Starting simulation from: {current_time}")
print(f"Ending at: {now_rw}")
print(f"Generating data every 5 minutes for {NUM_METERS} meters\n")

while True:
    now_rw = datetime.now(RWANDA_TZ)

    # Stop once we catch up to real time
    if current_time > now_rw:
        print("Stopping: reached current Rwanda time.")
        break

    for meter_id in range(1, NUM_METERS + 1):
        data = generate_meter_data(meter_id, current_time)
        topic = TOPIC_TEMPLATE.format(f"{meter_id:010d}")
        client.publish(topic, json.dumps(data))

    print(f"Published {NUM_METERS} readings for timestamp: {current_time}")

    # Move forward by 5 minutes
    current_time += timedelta(seconds=INTERVAL_SECONDS)

    # Accelerated sleep
    time.sleep(max(0.1, INTERVAL_SECONDS / SIMULATION_SPEED))

print("Simulation completed successfully.")
