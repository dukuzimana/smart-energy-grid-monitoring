-- ======================================================
-- SMART ENERGY GRID MONITORING SYSTEM
-- Steps 3 to 6 script
-- ======================================================

-- ===============================
-- STEP 3.1: Converting postgreSQL table to TimescaleDB hypertable.
-- ===============================
-- Enable TimescaleDB
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Convert existing table to hypertable (migrate existing data)
SELECT create_hypertable(
    'energy_readings',
    'timestamp',
    chunk_time_interval => INTERVAL '1 day',
    migrate_data => true
);
-- =========================================
--  STEP 3.2 Sript was created to generate data using Vs code
-- ==========================================
-- ===============================
-- STEP 3.3: BASELINE QUERIES (with execution time)
-- ===============================

-- EXPLAIN ANALYZE is being used to show execution time

-- Query 1: Average power per hour today
EXPLAIN ANALYZE
SELECT time_bucket('1 hour', timestamp) AS hour,
       AVG(power) AS avg_power
FROM energy_readings
WHERE timestamp >= DATE_TRUNC('day', NOW())
GROUP BY hour
ORDER BY hour;

-- Query 2: Peak consumption periods in past week
EXPLAIN ANALYZE
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) AS avg_power
FROM energy_readings
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY period
ORDER BY avg_power DESC
LIMIT 10;

-- Query 3: Monthly consumption per meter
EXPLAIN ANALYZE
SELECT meter_id,
       DATE_TRUNC('month', timestamp) AS month,
       SUM(energy) AS total_energy
FROM energy_readings
GROUP BY meter_id, month
ORDER BY month, total_energy DESC;

-- Query 4: Full dataset scan
EXPLAIN ANALYZE
SELECT COUNT(*) AS total_rows,
       AVG(power) AS avg_power,
       MAX(power) AS max_power,
       MIN(power) AS min_power
FROM energy_readings;

-- ===============================
-- STEP 4: CHUNK INTERVAL EXPERIMENTATION
-- ===============================
-- 4.1.1 Create 3-hour chunk hypertable
CREATE TABLE energy_readings_3h (LIKE energy_readings INCLUDING ALL);
SELECT create_hypertable('energy_readings_3h', 'timestamp', chunk_time_interval => INTERVAL '3 hours');

-- 4.1.2Create 1-week chunk hypertable
CREATE TABLE energy_readings_week (LIKE energy_readings INCLUDING ALL);
SELECT create_hypertable('energy_readings_week', 'timestamp', chunk_time_interval => INTERVAL '1 week');

-- 4.2 loading the data into new hypertables
INSERT INTO energy_readings_3h SELECT * FROM energy_readings;
INSERT INTO energy_readings_week SELECT * FROM energy_readings;

-- ===============================
-- STEP 4: RE-RUN BASELINE QUERIES FOR COMPARISON (EXPLAIN ANALYZE)
-- ===============================
--Restarting PosgreSQL to ensure cold cache condition
-- energy_readings_3h 

-- Query 1: Average power per hour today
EXPLAIN ANALYZE
SELECT time_bucket('1 hour', timestamp) AS hour,
       AVG(power) AS avg_power
FROM energy_readings_3h
WHERE timestamp >= DATE_TRUNC('day', NOW())
GROUP BY hour
ORDER BY hour;

-- Query 2: Peak consumption periods in past week
EXPLAIN ANALYZE
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) AS avg_power
FROM energy_readings_3h
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY period
ORDER BY avg_power DESC
LIMIT 10;

-- Query 3: Monthly consumption per meter
EXPLAIN ANALYZE
SELECT meter_id,
       DATE_TRUNC('month', timestamp) AS month,
       SUM(energy) AS total_energy
FROM energy_readings_3h
GROUP BY meter_id, month
ORDER BY month, total_energy DESC;

-- Query 4: Full dataset scan
EXPLAIN ANALYZE
SELECT COUNT(*) AS total_rows,
       AVG(power) AS avg_power,
       MAX(power) AS max_power,
       MIN(power) AS min_power
FROM energy_readings_3h;



-- energy_readings_week 

-- Query 1: Average power per hour today
EXPLAIN ANALYZE
SELECT time_bucket('1 hour', timestamp) AS hour,
       AVG(power) AS avg_power
FROM energy_readings_week
WHERE timestamp >= DATE_TRUNC('day', NOW())
GROUP BY hour
ORDER BY hour;

-- Query 2: Peak consumption periods in past week
EXPLAIN ANALYZE
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) AS avg_power
FROM energy_readings_week
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY period
ORDER BY avg_power DESC
LIMIT 10;

-- Query 3: Monthly consumption per meter
EXPLAIN ANALYZE
SELECT meter_id,
       DATE_TRUNC('month', timestamp) AS month,
       SUM(energy) AS total_energy
FROM energy_readings_week
GROUP BY meter_id, month
ORDER BY month, total_energy DESC;

-- Query 4: Full dataset scan
EXPLAIN ANALYZE
SELECT COUNT(*) AS total_rows,
       AVG(power) AS avg_power,
       MAX(power) AS max_power,
       MIN(power) AS min_power
FROM energy_readings_week;

-- Chunk distribution analysis
SELECT chunk_schema, chunk_name, range_start, range_end,
       pg_size_pretty(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)) AS chunk_size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'energy_readings';

-- ===============================
-- STEP 5: COMPRESSION IMPLEMENTATION
-- ===============================

-- 5.0 BEFORE COMPRESSION
-- 5.0.1 Check hypertable disk usage before compression
SELECT hypertable_name,
       pg_size_pretty(hypertable_size(format('%I', hypertable_name)::regclass)) AS size
FROM timescaledb_information.hypertables;

-- 5.0.2 Re-run queries before compression to record execution times

--Restarting PosgreSQL to ensure cold cache condition

--energy_readings
--QUERY2
EXPLAIN ANALYZE
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) AS avg_power
FROM energy_readings
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY period
ORDER BY avg_power DESC
LIMIT 10;

--QUERY 3
EXPLAIN ANALYZE
SELECT meter_id,
       DATE_TRUNC('month', timestamp) AS month,
       SUM(energy) AS total_energy
FROM energy_readings
GROUP BY meter_id, month
ORDER BY month, total_energy DESC;

--energy_readings_3h
--QUERY2
EXPLAIN ANALYZE
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) AS avg_power
FROM energy_readings_3h
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY period
ORDER BY avg_power DESC
LIMIT 10;

--QUERY 3
EXPLAIN ANALYZE
SELECT meter_id,
       DATE_TRUNC('month', timestamp) AS month,
       SUM(energy) AS total_energy
FROM energy_readings_3h
GROUP BY meter_id, month
ORDER BY month, total_energy DESC;


--energy_readings_week

--QUERY2
EXPLAIN ANALYZE
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) AS avg_power
FROM energy_readings_week
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY period
ORDER BY avg_power DESC
LIMIT 10;

--QUERY 3
EXPLAIN ANALYZE
SELECT meter_id,
       DATE_TRUNC('month', timestamp) AS month,
       SUM(energy) AS total_energy
FROM energy_readings_week
GROUP BY meter_id, month 
ORDER BY month, total_energy DESC; 

-- 5.1 APPLY COMPRESSION SETTINGS
ALTER TABLE energy_readings
SET (timescaledb.compress, timescaledb.compress_orderby = 'timestamp DESC');

ALTER TABLE energy_readings_3h
SET (timescaledb.compress, timescaledb.compress_orderby = 'timestamp DESC');

ALTER TABLE energy_readings_week
SET (timescaledb.compress, timescaledb.compress_orderby = 'timestamp DESC');

-- 5.2 MANUAL COMPRESSION OF EXISTING CHUNKS
-- compress all existing chunks immediately
SELECT compress_chunk(chunk_name)
FROM show_chunks('energy_readings') AS c;

SELECT compress_chunk(chunk_name)
FROM show_chunks('energy_readings_3h') AS c;

SELECT compress_chunk(chunk_name)
FROM show_chunks('energy_readings_week') AS c;

-- 5.3 ADD COMPRESSION POLICY FOR FUTURE CHUNKS
SELECT add_compression_policy('energy_readings', INTERVAL '24 hours');
SELECT add_compression_policy('energy_readings_3h', INTERVAL '24 hours');
SELECT add_compression_policy('energy_readings_week', INTERVAL '24 hours');

-- 5.4 AFTER COMPRESSION
-- 5.4.1 Check disk usage again
SELECT hypertable_name,
       pg_size_pretty(hypertable_size(format('%I', hypertable_name)::regclass)) AS size
FROM timescaledb_information.hypertables;

-- 5.4.2 Re-run queries to record execution times after compression
--Restarting PosgreSQL to ensure cold cache condition

--energy_readings
--QUERY2
EXPLAIN ANALYZE
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) AS avg_power
FROM energy_readings
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY period
ORDER BY avg_power DESC
LIMIT 10;

--QUERY 3
EXPLAIN ANALYZE
SELECT meter_id,
       DATE_TRUNC('month', timestamp) AS month,
       SUM(energy) AS total_energy
FROM energy_readings
GROUP BY meter_id, month
ORDER BY month, total_energy DESC;

--energy_readings_3h
--QUERY2
EXPLAIN ANALYZE
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) AS avg_power
FROM energy_readings_3h
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY period
ORDER BY avg_power DESC
LIMIT 10;

--QUERY 3
EXPLAIN ANALYZE
SELECT meter_id,
       DATE_TRUNC('month', timestamp) AS month,
       SUM(energy) AS total_energy
FROM energy_readings_3h
GROUP BY meter_id, month
ORDER BY month, total_energy DESC;


--energy_readings_week

--QUERY2
EXPLAIN ANALYZE
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) AS avg_power
FROM energy_readings_week
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY period
ORDER BY avg_power DESC
LIMIT 10;

--QUERY 3
EXPLAIN ANALYZE
SELECT meter_id,
       DATE_TRUNC('month', timestamp) AS month,
       SUM(energy) AS total_energy
FROM energy_readings_week
GROUP BY meter_id, month 
ORDER BY month, total_energy DESC; 

-- 5.5 CALCULATE COMPRESSION RATIO AND PERFORMANCE CHANGE
-- Compression ratio = uncompressed_size / compressed_size
-- Query performance difference = % change in execution time


-- ===============================
-- STEP 6: CONTINUOUS AGGREGATIONS
-- ===============================
-- Create 15-minute continuous aggregate view
CREATE MATERIALIZED VIEW energy_readings_15min
WITH (timescaledb.continuous) AS
SELECT meter_id,
       time_bucket('15 minutes', timestamp) AS bucket,
       AVG(power) AS avg_power,
       MAX(power) AS max_power,
       SUM(energy) AS total_energy
FROM energy_readings
GROUP BY meter_id, bucket;

-- Add refresh policy
SELECT add_continuous_aggregate_policy(
    'energy_readings_15min',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '15 minutes'
);

-- Compare raw vs aggregated query (sample meter_id) with EXPLAIN ANALYZE
-- Raw data
EXPLAIN ANALYZE
SELECT meter_id,
       time_bucket('15 minutes', timestamp) AS bucket,
       AVG(power) AS avg_power
FROM energy_readings
WHERE timestamp >= NOW() - INTERVAL '1 day'
  AND meter_id = '0000001234'
GROUP BY meter_id, bucket
ORDER BY bucket;

-- Continuous aggregate
EXPLAIN ANALYZE
SELECT meter_id, bucket, avg_power
FROM energy_readings_15min
WHERE bucket >= NOW() - INTERVAL '1 day'
  AND meter_id = '0000001234'
ORDER BY bucket;

 --Hourly continuous aggregate
CREATE MATERIALIZED VIEW energy_readings_1h
WITH (timescaledb.continuous) AS
SELECT meter_id,
       time_bucket('1 hour', timestamp) AS bucket,
       AVG(power) AS avg_power,
       MAX(power) AS max_power,
       SUM(energy) AS total_energy
FROM energy_readings
GROUP BY meter_id, bucket;

-- Add refresh policy for hourly aggregate
SELECT add_continuous_aggregate_policy(
    'energy_readings_1h',
    start_offset => INTERVAL '7 days',   -- adjust based on how far back you want to refresh
    end_offset   => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

--  Daily continuous aggregate
CREATE MATERIALIZED VIEW energy_readings_1d
WITH (timescaledb.continuous) AS
SELECT meter_id,
       time_bucket('1 day', timestamp) AS bucket,
       AVG(power) AS avg_power,
       MAX(power) AS max_power,
       SUM(energy) AS total_energy
FROM energy_readings
GROUP BY meter_id, bucket;

-- Add refresh policy for daily aggregate
SELECT add_continuous_aggregate_policy(
    'energy_readings_1d',
    start_offset => INTERVAL '30 days',   -- refresh last 30 days
    end_offset   => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);


-- Compare raw vs aggregated queries

-- Hourly aggregate vs raw data
EXPLAIN ANALYZE
SELECT meter_id,
       time_bucket('1 hour', timestamp) AS bucket,
       AVG(power) AS avg_power
FROM energy_readings
WHERE timestamp >= NOW() - INTERVAL '7 days'
  AND meter_id = '0000001234'
GROUP BY meter_id, bucket
ORDER BY bucket;

EXPLAIN ANALYZE
SELECT meter_id, bucket, avg_power
FROM energy_readings_1h
WHERE bucket >= NOW() - INTERVAL '7 days'
  AND meter_id = '0000001234'
ORDER BY bucket;

-- Daily aggregate vs raw data
EXPLAIN ANALYZE
SELECT meter_id,
       time_bucket('1 day', timestamp) AS bucket,
       AVG(power) AS avg_power
FROM energy_readings
WHERE timestamp >= NOW() - INTERVAL '30 days'
  AND meter_id = '0000001234'
GROUP BY meter_id, bucket
ORDER BY bucket;

EXPLAIN ANALYZE
SELECT meter_id, bucket, avg_power
FROM energy_readings_1d
WHERE bucket >= NOW() - INTERVAL '30 days'
  AND meter_id = '0000001234'
ORDER BY bucket;