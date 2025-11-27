from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import json
import os
from items import router as items_router

app = FastAPI()

app.include_router(items_router)

# JSON file to store users
USERS_FILE = "users.json"

# Make sure the file exists
if not os.path.exists(USERS_FILE):
    with open(USERS_FILE, "w") as f:
        json.dump([], f)

# Pydantic model
class User(BaseModel):
    username: str
    email: str
    phone: str

# Helper functions
def load_users():
    with open(USERS_FILE, "r") as f:
        return json.load(f)

def save_users(users):
    with open(USERS_FILE, "w") as f:
        json.dump(users, f, indent=4)

# Routes
@app.post("/signup")
def signup(user: User):
    users = load_users()

    # Check for duplicate email
    for u in users:
        if u["email"] == user.email:
            raise HTTPException(status_code=404, detail="Email already registered")

    new_user = {
        "id": len(users) + 1,
        "username": user.username,
        "email": user.email,
        "phone": user.phone
    }

    users.append(new_user)
    save_users(users)

    return {"message": "User signed up successfully", "user": new_user}

#Login model
class Loginrequest(BaseModel):
    username: str
    email: str

#Login route
@app.post("/login")
def login(data : Loginrequest):
    users = load_users()

    for u in users :
        if u["email"] == data.email and u["username"] == data.username:
            return {"Login successful."}
    
    raise HTTPException(status_code= 404, detail= "User not found")

@app.get("/")
def home():
    return {"message": "API is running!"}

@app.get("/users")
def get_users():
    users = load_users()
    return users