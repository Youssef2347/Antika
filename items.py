from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Request, Depends
import json
import os
import shutil
from datetime import datetime

router = APIRouter()

ITEMS_FILE = "items.json"
BIDS_FILE = "bids.json"
NOTIFICATIONS_FILE = "notifications.json"

# Create files/folders if missing
if not os.path.exists(ITEMS_FILE):
    with open(ITEMS_FILE, "w") as f:
        json.dump([], f)

if not os.path.exists(BIDS_FILE):
    with open(BIDS_FILE, "w") as f:
        json.dump([], f)

if not os.path.exists(NOTIFICATIONS_FILE):
    with open(NOTIFICATIONS_FILE, "w") as f:
        json.dump([], f)

if not os.path.exists("images"):
    os.makedirs("images")


def load_items():
    with open(ITEMS_FILE, "r") as f:
        return json.load(f)


def save_items(items):
    with open(ITEMS_FILE, "w") as f:
        json.dump(items, f, indent=4)


def load_bids():
    with open(BIDS_FILE, "r") as f:
        return json.load(f)


def save_bids(bids):
    with open(BIDS_FILE, "w") as f:
        json.dump(bids, f, indent=4)


def load_notifications():
    with open(NOTIFICATIONS_FILE, "r") as f:
        return json.load(f)


def save_notifications(notifications):
    with open(NOTIFICATIONS_FILE, "w") as f:
        json.dump(notifications, f, indent=4)


def load_users():
    with open("users.json", "r") as f:
        return json.load(f)


def get_user_id(request: Request):
    user_id = request.headers.get("user-id")
    if user_id is None:
        raise HTTPException(status_code=401, detail="User ID missing — user not logged in")
    return int(user_id)


def check_expired_items_and_notify_winners():
    items = load_items()
    notifications = load_notifications()
    users = load_users()
    
    # For demo purposes, we'll manually mark items as sold via an endpoint
    # This function is kept for future use if you want to add expiration later
    pass


@router.post("/upload-item")
async def upload_item(
    request: Request,
    title: str = Form(...),
    description: str = Form(...),
    starting_price: float = Form(...),
    image: UploadFile = File(...)
):
    user_id = get_user_id(request)

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
        "image": image_path,
        "highest_bidder_id": None,
        "status": "active",
        "created_at": datetime.now().isoformat()
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
def my_items(request: Request):
    user_id = get_user_id(request)
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


@router.post("/items/{item_id}/bid")
def place_bid(item_id: int, request: Request, bid_amount: float = Form(...)):
    user_id = get_user_id(request)
    
    # Load items and bids
    items = load_items()
    bids = load_bids()
    
    # Find the item
    item = next((item for item in items if item["id"] == item_id), None)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    # Check if item is still active
    if item["status"] != "active":
        raise HTTPException(status_code=400, detail="This auction has ended")
    
    # Check if user is not the item owner
    if item["user_id"] == user_id:
        raise HTTPException(status_code=400, detail="You cannot bid on your own item")
    
    # Check if bid amount is higher than current price
    if bid_amount <= item["current_price"]:
        raise HTTPException(
            status_code=400, 
            detail=f"Bid amount must be higher than current price (${item['current_price']})"
        )
    
    # Create new bid
    new_bid = {
        "id": len(bids) + 1,
        "item_id": item_id,
        "user_id": user_id,
        "amount": bid_amount,
        "timestamp": datetime.now().isoformat()
    }
    
    # Update item with new highest bid
    item["current_price"] = bid_amount
    item["highest_bidder_id"] = user_id
    
    # Save changes
    bids.append(new_bid)
    save_bids(bids)
    save_items(items)
    
    return {
        "message": "Bid placed successfully",
        "bid": new_bid,
        "new_current_price": bid_amount
    }


@router.get("/items/{item_id}/bids")
def get_item_bids(item_id: int):
    bids = load_bids()
    item_bids = [bid for bid in bids if bid["item_id"] == item_id]
    
    # Sort bids by amount (highest first)
    item_bids.sort(key=lambda x: x["amount"], reverse=True)
    
    return {
        "item_id": item_id,
        "bids": item_bids,
        "total_bids": len(item_bids)
    }


@router.get("/my-bids")
def get_my_bids(request: Request):
    user_id = get_user_id(request)
    bids = load_bids()
    items = load_items()
    
    my_bids = [bid for bid in bids if bid["user_id"] == user_id]
    
    # Add item details to each bid
    for bid in my_bids:
        item = next((item for item in items if item["id"] == bid["item_id"]), None)
        bid["item_title"] = item["title"] if item else "Unknown Item"
        bid["item_image"] = item["image"] if item else None
        bid["item_status"] = item["status"] if item else "unknown"
    
    return {
        "user_id": user_id,
        "bids": my_bids,
        "total_bids": len(my_bids)
    }


@router.get("/my-notifications")
def get_my_notifications(request: Request):
    user_id = get_user_id(request)
    notifications = load_notifications()
    
    user_notifications = [n for n in notifications if n["user_id"] == user_id]
    
    # Sort by latest first
    user_notifications.sort(key=lambda x: x["timestamp"], reverse=True)
    
    return {
        "user_id": user_id,
        "notifications": user_notifications,
        "unread_count": len([n for n in user_notifications if not n["read"]])
    }


@router.post("/notifications/{notification_id}/read")
def mark_notification_read(notification_id: int, request: Request):
    user_id = get_user_id(request)
    notifications = load_notifications()
    
    notification = next((n for n in notifications if n["id"] == notification_id and n["user_id"] == user_id), None)
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    
    notification["read"] = True
    save_notifications(notifications)
    
    return {"message": "Notification marked as read"}


@router.post("/items/{item_id}/end-auction")
def end_auction(item_id: int, request: Request):
    """Manually end an auction and notify the winner"""
    user_id = get_user_id(request)
    items = load_items()
    notifications = load_notifications()
    users = load_users()
    
    # Find the item
    item = next((item for item in items if item["id"] == item_id), None)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    
    # Check if user owns the item
    if item["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="Only the item owner can end the auction")
    
    # Check if auction is still active
    if item["status"] != "active":
        raise HTTPException(status_code=400, detail="Auction has already ended")
    
    # Mark item as sold
    item["status"] = "sold"
    
    # Notify the winner if there was a bid
    if item["highest_bidder_id"] is not None:
        winner_id = item["highest_bidder_id"]
        
        # Create notification
        new_notification = {
            "id": len(notifications) + 1,
            "user_id": winner_id,
            "item_id": item["id"],
            "item_title": item["title"],
            "message": f"🎉 You won the auction for '{item['title']}' with a bid of ${item['current_price']}!",
            "type": "win",
            "timestamp": datetime.now().isoformat(),
            "read": False
        }
        notifications.append(new_notification)
    
    save_items(items)
    save_notifications(notifications)
    
    return {
        "message": "Auction ended successfully",
        "winner_id": item["highest_bidder_id"],
        "winning_price": item["current_price"]
    }