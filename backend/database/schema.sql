-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Districts Table
CREATE TABLE districts (
    id SERIAL PRIMARY KEY,
    dist_code VARCHAR(10) UNIQUE,
    dist_name VARCHAR(100),
    geom GEOMETRY(MultiPolygon, 4326)
);

-- Mandals Table
CREATE TABLE mandals (
    id SERIAL PRIMARY KEY,
    mandal_code VARCHAR(10) UNIQUE,
    mandal_name VARCHAR(100),
    dist_code VARCHAR(10) REFERENCES districts(dist_code),
    geom GEOMETRY(MultiPolygon, 4326)
);

-- Villages Table
CREATE TABLE villages (
    id SERIAL PRIMARY KEY,
    village_code VARCHAR(10) UNIQUE,
    village_name VARCHAR(100),
    mandal_code VARCHAR(10) REFERENCES mandals(mandal_code),
    geom GEOMETRY(MultiPolygon, 4326)
);

-- Parcels Table (AIKOSH Data)
CREATE TABLE land_parcels (
    id SERIAL PRIMARY KEY,
    ulpin VARCHAR(50) UNIQUE,
    survey_number VARCHAR(50),
    village_code VARCHAR(10) REFERENCES villages(village_code),
    mandal_code VARCHAR(10) REFERENCES mandals(mandal_code),
    geom GEOMETRY(MultiPolygon, 4326)
);

-- API Audit Log Table (For DPDP Act Compliance)
CREATE TABLE api_audit_logs (
    id SERIAL PRIMARY KEY,
    request_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    anonymized_device_id VARCHAR(255),
    requested_lat NUMERIC(10, 7),
    requested_lng NUMERIC(10, 7),
    gps_accuracy_meters NUMERIC(5, 2),
    resolved_ulpin VARCHAR(50),
    status VARCHAR(50)
);

-- Spatial Indexing
CREATE INDEX idx_districts_geom ON districts USING GIST (geom);
CREATE INDEX idx_mandals_geom ON mandals USING GIST (geom);
CREATE INDEX idx_villages_geom ON villages USING GIST (geom);
CREATE INDEX idx_land_parcels_geom ON land_parcels USING GIST (geom);
CREATE INDEX idx_audit_timestamp ON api_audit_logs(request_timestamp);
