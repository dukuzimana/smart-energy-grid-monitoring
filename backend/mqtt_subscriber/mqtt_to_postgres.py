
import json
import psycopg2
from paho.mqtt import client as mqtt_client

# PostgreSQL connection
conn = psycopg2.connect(
    dbname="smart_grid",
    user="postgres",
    password="Umutoni@999",
    host="localhost",
    port="5432"
)
cursor = conn.cursor()

# MQTT settings
BROKER = "localhost"
TOPIC = "energy/meters/#"

def on_message(client, userdata, msg):
    data = json.loads(msg.payload.decode())

    cursor.execute("""
        INSERT INTO energy_readings
        (meter_id, timestamp, power, voltage, current, frequency, energy)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (
        data["meter_id"],
        data["timestamp"],
        data["power"],
        data["voltage"],
        data["current"],
        data["frequency"],
        data["energy"]
    ))
    conn.commit()
    print("Inserted:", data["meter_id"])

client = mqtt_client.Client()
client.connect(BROKER)
client.subscribe(TOPIC)
client.on_message = on_message

print("Listening for MQTT messages...") 
client.loop_forever()

