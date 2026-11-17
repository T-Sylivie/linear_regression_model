import io
from pathlib import Path
from typing import Literal

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, ConfigDict, Field
from sklearn.base import clone
from sklearn.linear_model import SGDRegressor
from sklearn.metrics import mean_squared_error

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "best_model.pkl"
TRAIN_DATA_PATH = BASE_DIR / "training_data.csv"

FEATURES = [
    "Distance (KM)", "Pickup - Weekday (Mo = 1)", "Pickup Hour",
    "Pickup Lat", "Pickup Long", "Destination Lat", "Destination Long",
    "No_Of_Orders", "Age", "Average_Rating", "Platform Type", "Personal or Business",
]
TARGET = "Delivery Time (min)"

model = joblib.load(MODEL_PATH)

app = FastAPI(
    title="Nairobi Delivery Time Prediction API",
    description="Predicts how long a motorbike delivery in Nairobi takes (minutes) from pick-up to arrival.",
    version="1.0.0",
)

# CORS: only the Render site and the local Flutter web address can call the API from a browser.
# No "*", only GET/POST and the headers we need, and no credentials since there are no logins.
ALLOWED_ORIGINS = [
    "https://nairobi-delivery-time-api.onrender.com",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Accept"],
    allow_credentials=False,
)


class DeliveryInput(BaseModel):
    model_config = ConfigDict(
        strict=True,
        json_schema_extra={
            "example": {
                "distance_km": 9,
                "pickup_weekday": 3,
                "pickup_hour": 9,
                "pickup_lat": -1.276574,
                "pickup_long": 36.851365,
                "destination_lat": -1.252796,
                "destination_long": 36.800313,
                "rider_no_of_orders": 2322,
                "rider_age_days": 966,
                "rider_average_rating": 14.4,
                "platform_type": 3,
                "personal_or_business": "Business",
            }
        },
    )

    distance_km: float = Field(..., ge=1, le=50, description="Distance in km")
    pickup_weekday: int = Field(..., ge=1, le=7, description="Monday = 1, Sunday = 7")
    pickup_hour: int = Field(..., ge=0, le=23)
    pickup_lat: float = Field(..., ge=-1.50, le=-1.00)
    pickup_long: float = Field(..., ge=36.50, le=37.10)
    destination_lat: float = Field(..., ge=-1.50, le=-1.00)
    destination_long: float = Field(..., ge=36.50, le=37.10)
    rider_no_of_orders: int = Field(..., ge=0, le=10000)
    rider_age_days: int = Field(..., ge=0, le=4000, description="Days since the rider's first delivery")
    rider_average_rating: float = Field(..., ge=0, le=15.2)
    platform_type: int = Field(..., ge=1, le=4)
    personal_or_business: Literal["Business", "Personal"]


def to_model_frame(data: DeliveryInput) -> pd.DataFrame:
    row = {
        "Distance (KM)": data.distance_km,
        "Pickup - Weekday (Mo = 1)": data.pickup_weekday,
        "Pickup Hour": data.pickup_hour,
        "Pickup Lat": data.pickup_lat,
        "Pickup Long": data.pickup_long,
        "Destination Lat": data.destination_lat,
        "Destination Long": data.destination_long,
        "No_Of_Orders": data.rider_no_of_orders,
        "Age": data.rider_age_days,
        "Average_Rating": data.rider_average_rating,
        "Platform Type": data.platform_type,
        "Personal or Business": data.personal_or_business,
    }
    return pd.DataFrame([row], columns=FEATURES)


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")


@app.post("/predict")
def predict(data: DeliveryInput):
    prediction = float(model.predict(to_model_frame(data))[0])
    return {"predicted_delivery_time_minutes": round(prediction, 2)}


@app.post("/retrain")
async def retrain(file: UploadFile = File(...)):
    global model

    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file.")

    try:
        new_data = pd.read_csv(io.BytesIO(await file.read()))
    except Exception:
        raise HTTPException(status_code=400, detail="The file could not be read as a CSV.")

    missing = [col for col in FEATURES + [TARGET] if col not in new_data.columns]
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing columns: {missing}")

    new_data = new_data[FEATURES + [TARGET]].dropna()
    new_data = new_data[new_data[TARGET] >= 1]
    if len(new_data) == 0:
        raise HTTPException(status_code=400, detail="No valid rows found in the file.")

    X_new, y_new = new_data[FEATURES], new_data[TARGET]
    mse_before = mean_squared_error(y_new, model.predict(X_new))

    if isinstance(model.named_steps["model"], SGDRegressor):
        X_new_prep = model.named_steps["preprocessor"].transform(X_new)
        model.named_steps["model"].partial_fit(X_new_prep, y_new)
        method = "partial_fit on the new rows"
        total_rows = len(new_data)
    else:
        original = pd.read_csv(TRAIN_DATA_PATH)
        combined = pd.concat([original, new_data], ignore_index=True)
        updated_model = clone(model)
        updated_model.fit(combined[FEATURES], combined[TARGET])
        model = updated_model
        combined.to_csv(TRAIN_DATA_PATH, index=False)
        method = "refit on original training data + new rows"
        total_rows = len(combined)

    joblib.dump(model, MODEL_PATH)
    mse_after = mean_squared_error(y_new, model.predict(X_new))

    return {
        "message": "Model retrained and now used by /predict.",
        "method": method,
        "new_rows_used": int(len(new_data)),
        "total_training_rows": int(total_rows),
        "mse_on_new_data_before": round(float(mse_before), 2),
        "mse_on_new_data_after": round(float(mse_after), 2),
    }