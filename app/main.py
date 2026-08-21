from typing import Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import os

APP_ENV = os.getenv("APP_ENV", "development")
app = FastAPI(title=f"Simple app API [{APP_ENV.upper()}]")

users_db = [
    {
        "id": 1, 
        "name": "Иван", 
        "surname": "Иванов", 
        "requiredField": "Важные данные", 
        "optionalField": "Заметки"
    },
    {
        "id": 2, 
        "name": "Петр", 
        "surname": "Петров", 
        "requiredField": "Другие данные", 
        "optionalField": None
    }
]

class UserCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=50, pattern=r"^[А-Яа-яЁёA-Za-z]+$")
    surname: str = Field(..., min_length=2, max_length=50, pattern=r"^[А-Яа-яЁёA-Za-z]+$")
    requiredField: str = Field(..., min_length=1, max_length=100)
    optionalField: Optional[str] = Field(None, max_length=255)


@app.get("/")
def read_root():
    return {"message": "Hello, World!"}


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/api/users")
def get_users():
    return {"users": users_db}


@app.post("/api/users", status_code=201)
def create_user(user: UserCreate):
    new_id = max([u["id"] for u in users_db], default=0) + 1
    
    new_user = {"id": new_id, **user.model_dump()}
    
    users_db.append(new_user)
    return new_user


@app.get("/api/users/{user_id}")
def get_user(user_id: int):
    for user in users_db:
        if user["id"] == user_id:
            return user
    raise HTTPException(status_code=404, detail="User not found")


@app.delete("/api/users/{user_id}")
def delete_user(user_id: int):
    for index, user in enumerate(users_db):
        if user["id"] == user_id:
            deleted_user = users_db.pop(index)
            return {"message": f"User {deleted_user['name']} {deleted_user['surname']} deleted successfully"}
    raise HTTPException(status_code=404, detail="User not found")
