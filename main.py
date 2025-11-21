from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

users_db = []

class User(BaseModel):
    username: str
    email: str
    phone: str

@app.post("/signup")
def signup(user: User):
    for existing_user in users_db:
        if existing_user["email"] == user.email:
            raise HTTPException(status_code=400, detail="Email already registered")

    new_user = {
        "id": len(users_db) + 1,
        "username": user.username,
        "email": user.email,
        "phone": user.phone
    }
    users_db.append(new_user)

    return {"message": "User signed up successfully", "user": new_user}
