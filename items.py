from fastapi import APIRouter, File, UploadFile, HTTPException
import os
import json
import shutil

router = APIRouter()

ITEMS_FILE = "items.json"

if not os.path.exists(ITEMS_FILE):
    with open(ITEMS_FILE, "w") as f:
        json.dump([], f, indent=4)

def load_items():
    with open(ITEMS_FILE, "r") as f:
        return json.load(f)

def save_items(items):
    with open(ITEMS_FILE, "w") as f:
        json.dump(items, f, indent=4)

@router.post("/upload-item")
def upload_item(
    user_id: int,
    description: str,
    starting_price: float,
    image: UploadFile = File(...)
):
    items = load_items()

    images_folder = "images"
    os.makedirs(images_folder, exist_ok=True)

    image_path = f"{images_folder}/{image.filename}"

    with open(image_path, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    new_item = {
        "id": len(items) + 1,
        "user_id": user_id,
        "description": description,
        "starting_price": starting_price,
        "image_path": image_path
    }

    items.append(new_item)
    save_items(items)

    return {"message": "Item added", "item": new_item}


@router.get("/my-items")
def my_items(user_id: int):
    items = load_items()
    user_items = [i for i in items if i["user_id"] == user_id]
    return user_items

@router.get("/search")
def search_items(q: str):
    with open(ITEMS_FILE, "r") as f:
        items = json.load(f)

    # Convert search text to lowercase
    query = q.lower()

    # Find matching items
    results = [
        item for item in items 
        if query in item["description"].lower() or query in item["title"].lower()
    ]

    return {"results": results, "count": len(results)}

@router.get("/items")
def get_all_items():
    items = load_items()
    return items
