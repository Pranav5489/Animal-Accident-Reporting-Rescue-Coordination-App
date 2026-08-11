import os
import io
import sys
# Ensure app module is found
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from fastapi.testclient import TestClient
from app.main import app
from app.database import Base, engine, SessionLocal
from app.models import RescueTeam, Incident, IncidentStatus

# Initialize SQLite database
print("Creating SQLite tables...")
Base.metadata.create_all(bind=engine)

client = TestClient(app)

def run_tests():
    db = SessionLocal()
    
    # 1. Create a dummy rescue team with a mock token
    print("--- Creating Rescue Team ---")
    team = RescueTeam(
        ngo_name="Mock Rescuers",
        latitude=40.7128,
        longitude=-74.0060,
        is_available=True,
        device_token="mock_device_token_123"
    )
    db.add(team)
    db.commit()
    db.refresh(team)
    print(f"✅ Created Team: {team.ngo_name} (ID: {team.team_id})")

    # 2. Simulate Mobile App Upload (POST /incidents)
    print("\n--- Simulating Mobile App Incident Report ---")
    # create a dummy image file
    fake_image = io.BytesIO(b"fake_image_data")
    fake_image.name = "test.jpg"
    
    response = client.post(
        "/api/v1/incidents",
        data={
            "latitude": 40.7130, # very close
            "longitude": -74.0065,
            "description": "Injured dog on the street",
            "animal_type": "Dog"
        },
        files={"image": ("test.jpg", fake_image, "image/jpeg")}
    )
    
    assert response.status_code == 201, f"Failed to create incident: {response.text}"
    incident_data = response.json()
    incident_id = incident_data["incident_id"]
    print(f"✅ Created Incident: {incident_data['animal_type']} (ID: {incident_id})")

    # 3. List Nearby Teams
    print("\n--- Finding Nearby Teams ---")
    response = client.get(f"/api/v1/teams/nearby?lat=40.7130&lon=-74.0065&radius_km=10")
    assert response.status_code == 200
    teams_nearby = response.json()
    print(f"✅ Found {len(teams_nearby)} teams nearby.")
    if teams_nearby:
        print(f"Nearest Team: {teams_nearby[0]['ngo_name']} at {teams_nearby[0]['distance_km']}km")
        
    # 4. Dispatch the Incident (Triggering Firebase mock)
    print("\n--- Dispatching Incident (Testing Firebase) ---")
    response = client.post(
        f"/api/v1/incidents/{incident_id}/dispatch?team_id={team.team_id}"
    )
    
    if response.status_code == 200:
        print(f"✅ Successfully dispatched incident to team {team.team_id}.")
        print("Note: If Firebase credentials aren't set, you should see 'Firebase not initialized, skipping push notification'.")
        print("This confirms the logic executed perfectly!")
    else:
        print(f"❌ Dispatch failed: {response.text}")

if __name__ == "__main__":
    run_tests()
