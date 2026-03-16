from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
import asyncpg
import os

app = FastAPI(title="Geo-Land TS API")

# Database connection pool
DB_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost/geoland")

async def get_db():
    conn = await asyncpg.connect(DB_URL)
    try:
        yield conn
    finally:
        await conn.close()

@app.get("/")
async def root():
    return {
        "project": "Geo-Land TS",
        "status": "Online",
        "region": "Telangana",
        "docs": "/docs",
        "endpoint": "/identify-land (POST)"
    }

class Location(BaseModel):
    latitude: float
    longitude: float
    accuracy: float
    device_id: Optional[str] = "anonymized_user"

class LandDetails(BaseModel):
    owner_name: str
    survey_number: str
    land_type: str
    area_acres: float
    ulpin: str
    village: str
    mandal: str

@app.post("/identify-land", response_model=LandDetails)
async def identify_land(loc: Location, db: asyncpg.Connection = Depends(get_db)):
    # 1. GPS Filtering (DPDP Requirement for "Noisy" data)
    if loc.accuracy > 5.0:
        await log_request(db, loc, status="REJECTED_LOW_ACCURACY")
        raise HTTPException(status_code=400, detail="GPS accuracy too low ( > 5m). Please wait for a better signal.")

    # 2. Logic Step A: Identify Parcel from coordinates
    query = """
        SELECT ulpin, survey_number, mandal_code, village_code
        FROM land_parcels
        WHERE ST_Contains(geom, ST_SetSRID(ST_Point($1, $2), 4326))
        LIMIT 1;
    """
    parcel = await db.fetchrow(query, loc.longitude, loc.latitude)
    
    if not parcel:
        await log_request(db, loc, status="NOT_FOUND")
        raise HTTPException(status_code=404, detail="No land records found for these coordinates.")

    # 3. Logic Step B: Query Bhu Bharati API (Simulated)
    owner_info = await mock_bhu_bharati_api(parcel['ulpin'])
    
    # 4. DPDP Audit Logging
    await log_request(db, loc, ulpin=parcel['ulpin'], status="SUCCESS")

    return LandDetails(
        owner_name=owner_info['owner_name'],
        survey_number=parcel['survey_number'],
        land_type=owner_info['land_type'],
        area_acres=owner_info['area_acres'],
        ulpin=parcel['ulpin'],
        village=parcel['village_code'],
        mandal=parcel['mandal_code']
    )

async def log_request(db, loc, ulpin=None, status="PENDING"):
    await db.execute("""
        INSERT INTO api_audit_logs (anonymized_device_id, requested_lat, requested_lng, gps_accuracy_meters, resolved_ulpin, status)
        VALUES ($1, $2, $3, $4, $5, $6)
    """, loc.device_id, loc.latitude, loc.longitude, loc.accuracy, ulpin, status)

async def mock_bhu_bharati_api(ulpin: str):
    # This simulates the Record of Rights query
    return {
        "owner_name": "వెన్నెల రాజేష్ (Vennela Rajesh)",
        "land_type": "Agricultural",
        "area_acres": 2.45
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
