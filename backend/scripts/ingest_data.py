import shapefile
import json
import asyncpg
import asyncio
import os

# Configuration
SHP_PATH = "data/telangana_parcels.shp"
DB_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost/geoland")

async def ingest_shapefile():
    conn = await asyncpg.connect(DB_URL)
    sf = shapefile.Reader(SHP_PATH)
    shapes = sf.shapes()
    records = sf.records()

    for i in range(len(shapes)):
        geom = shapes[i].__geo_interface__
        props = records[i]
        
        # New Schema Mapping (Example based on AIKOSH structure)
        mandal_code = props[0]
        mandal_name = props[1]
        village_code = props[2]
        village_name = props[3]
        ulpin = props[4]
        survey_no = props[5]

        # 1. Ensure Mandal exists
        await conn.execute("""
            INSERT INTO mandals (mandal_code, mandal_name)
            VALUES ($1, $2) ON CONFLICT (mandal_code) DO NOTHING
        """, mandal_code, mandal_name)

        # 2. Ensure Village exists
        await conn.execute("""
            INSERT INTO villages (village_code, village_name, mandal_code)
            VALUES ($1, $2, $3) ON CONFLICT (village_code) DO NOTHING
        """, village_code, village_name, mandal_code)

        # 3. Insert Parcel
        await conn.execute("""
            INSERT INTO land_parcels (ulpin, survey_number, village_code, mandal_code, geom)
            VALUES ($1, $2, $3, $4, ST_SetSRID(ST_GeomFromGeoJSON($5), 4326))
            ON CONFLICT (ulpin) DO NOTHING
        """, ulpin, survey_no, village_code, mandal_code, json.dumps(geom))

    await conn.close()
    print("Ingestion complete.")

if __name__ == "__main__":
    # asyncio.run(ingest_shapefile())
    print("Ingestion script ready. Place shapefiles in data/ directory.")
