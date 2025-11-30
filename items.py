from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Request
import json
import os
import shutil

router = APIRouter()

ITEMS_FILE = "items.json"

# Create files/folders if missing
if not os.path.exists(ITEMS_FILE):
    with open(ITEMS_FILE, "w") as f:
        json.dump([], f)

if not os.path.exists("images"):
    os.makedirs("images")


def load_items():
    with open(ITEMS_FILE, "r") as f:
        return json.load(f)


def save_items(items):
    with open(ITEMS_FILE, "w") as f:
        json.dump(items, f, indent=4)


@router.post("/upload-item")
async def upload_item(
    request: Request,
    title: str = Form(...),
    description: str = Form(...),
    starting_price: float = Form(...),
    image: UploadFile = File(...)
):
    # Get user ID from request headers
    user_id = request.headers.get("user-id")

    if user_id is None:
        raise HTTPException(status_code=401, detail="User ID missing — user not logged in")

    user_id = int(user_id)

    # Load items
    items = load_items()

    # Save uploaded image
    image_filename = f"{len(items) + 1}_{image.filename}"
    image_path = f"images/{image_filename}"

    with open(image_path, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    # Create item entry
    new_item = {
        "id": len(items) + 1,
        "user_id": user_id,
        "title": title,
        "description": description,
        "starting_price": starting_price,
        "current_price": starting_price,
        "image": image_path
    }

    items.append(new_item)
    save_items(items)

    return {
        "message": "Item uploaded successfully",
        "item": new_item
    }


@router.get("/items")
def get_all_items():
    return load_items()


@router.get("/my-items")
def my_items(user_id: int):
    items = load_items()
    return [i for i in items if i["user_id"] == user_id]


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