import os
import uuid
import random
from datetime import datetime, date

from fastapi import FastAPI, UploadFile, File, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from database import db, Image

UPLOAD_DIR = os.environ.get("UPLOAD_DIR", "./uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

app = FastAPI(title="Memor'IDEF API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory upload state: { session_id: { author, image_ids } }
upload_sessions: dict[str, dict] = {}

ANIMALS = [
    "Abeille", "Aigle", "Albatros", "Âne", "Antilope", "Araignée", "Autruche",
    "Baleine", "Belette", "Biche", "Blaireau", "Brebis", "Buffle",
    "Caméléon", "Canard", "Castor", "Cerf", "Chardonneret", "Chat", "Chauve-souris",
    "Cheval", "Chèvre", "Chouette", "Cigale", "Cigogne", "Cobra", "Coccinelle",
    "Colibri", "Coq", "Corbeau", "Cormoran", "Coyote", "Crabe", "Crapaud",
    "Crocodile", "Dauphin", "Écureuil", "Éléphant", "Épervier", "Escargot",
    "Faucon", "Flamant", "Fouine", "Fourmi", "Gazelle", "Girafe", "Gorille",
    "Grenouille", "Guépard", "Hérisson", "Héron", "Hibou", "Hippocampe",
    "Hirondelle", "Huître", "Iguane", "Jaguar", "Koala", "Lapin", "Léopard",
    "Lézard", "Libellule", "Lièvre", "Lion", "Loup", "Loutre", "Lynx",
    "Manchot", "Marmotte", "Martin-pêcheur", "Merle", "Mésange", "Moineau",
    "Mouette", "Mouflon", "Mouton", "Ours", "Panda", "Panthère", "Papillon",
    "Paon", "Perroquet", "Phoque", "Pie", "Pigeon", "Pingouin", "Pinson",
    "Poisson", "Poulpe", "Puma", "Raton-laveur", "Renard", "Requin",
    "Rossignol", "Rouge-gorge", "Salamandre", "Saumon", "Scarabée", "Serpent",
    "Souris", "Tigre", "Tortue", "Toucan",
]

ADJECTIVES = [
    "Adorable", "Agile", "Aimable", "Astucieux", "Audacieux", "Bavard",
    "Bondissant", "Brave", "Brillant", "Calme", "Câlin", "Charmant",
    "Coquin", "Costaud", "Courageux", "Créatif", "Curieux", "Délicat",
    "Discret", "Doux", "Drôle", "Dynamique", "Éblouissant", "Élégant",
    "Émerveillé", "Enchanteur", "Endiablé", "Énergique", "Enjoué", "Épanoui",
    "Espiègle", "Étoilé", "Facétieux", "Fantastique", "Farfelu", "Féroce",
    "Fidèle", "Fougueux", "Frileux", "Futé", "Galant", "Génial", "Gentil",
    "Gracieux", "Grognon", "Hardi", "Heureux", "Imaginatif", "Impétueux",
    "Ingénieux", "Intrépide", "Inventif", "Joueur", "Joyeux", "Léger",
    "Lumineux", "Lunatique", "Magique", "Magnifique", "Majestueux", "Malicieux",
    "Marrant", "Merveilleux", "Mignon", "Mystérieux", "Noble", "Pétillant",
    "Placide", "Polisson", "Radieux", "Rapide", "Rêveur", "Rieur", "Robuste",
    "Rusé", "Sage", "Sauvage", "Serein", "Solitaire", "Souriant", "Splendide",
    "Subtil", "Surprenant", "Taquin", "Téméraire", "Tendre", "Timide",
    "Tranquille", "Turbulent", "Vaillant", "Vif", "Vigilant", "Volubile",
    "Voyageur", "Zen", "Zélé", "Farceur", "Câlinou", "Rondouillard",
    "Flamboyant", "Pimpant",
]


def generate_author_name() -> str:
    return f"{random.choice(ADJECTIVES)} {random.choice(ANIMALS)}"


# --- Pydantic models ---

class ImageOut(BaseModel):
    id: int
    author: str
    upload_date: str
    date: str | None
    path: str
    location_x: float | None
    location_y: float | None


class ImageUpdate(BaseModel):
    date: str | None = None
    location_x: float | None = None
    location_y: float | None = None


class SessionOut(BaseModel):
    session_id: str
    author: str
    image_ids: list[int]


def image_to_dict(img: Image) -> dict:
    upload_date = img.upload_date
    if hasattr(upload_date, 'isoformat'):
        upload_date = upload_date.isoformat()
    d = img.date
    if hasattr(d, 'isoformat'):
        d = d.isoformat()
    return {
        "id": img.id,
        "author": img.author,
        "upload_date": str(upload_date) if upload_date else "",
        "date": str(d) if d else None,
        "path": img.path,
        "location_x": img.location_x,
        "location_y": img.location_y,
    }


# --- Routes ---

@app.get("/api/images", response_model=list[ImageOut])
def list_images(
    date_from: str | None = Query(None),
    date_to: str | None = Query(None),
):
    query = Image.select().order_by(Image.upload_date.desc())
    if date_from:
        query = query.where(Image.date >= date_from)
    if date_to:
        query = query.where(Image.date <= date_to)
    return [image_to_dict(img) for img in query]


@app.get("/api/images/unplaced", response_model=list[ImageOut])
def list_unplaced_images():
    query = (
        Image.select()
        .where(Image.location_x.is_null())
        .order_by(Image.upload_date.desc())
    )
    return [image_to_dict(img) for img in query]


@app.get("/api/images/{image_id}", response_model=ImageOut)
def get_image(image_id: int):
    try:
        img = Image.get_by_id(image_id)
    except Image.DoesNotExist:
        raise HTTPException(status_code=404, detail="Image not found")
    return image_to_dict(img)


@app.put("/api/images/{image_id}", response_model=ImageOut)
def update_image(image_id: int, data: ImageUpdate):
    try:
        img = Image.get_by_id(image_id)
    except Image.DoesNotExist:
        raise HTTPException(status_code=404, detail="Image not found")

    if data.date is not None:
        img.date = data.date
    if data.location_x is not None:
        img.location_x = data.location_x
    if data.location_y is not None:
        img.location_y = data.location_y
    img.save()
    return image_to_dict(img)


@app.delete("/api/images/{image_id}")
def delete_image(image_id: int):
    try:
        img = Image.get_by_id(image_id)
    except Image.DoesNotExist:
        raise HTTPException(status_code=404, detail="Image not found")

    filepath = os.path.join(UPLOAD_DIR, img.path)
    if os.path.exists(filepath):
        os.remove(filepath)

    # Remove from any session
    for session in upload_sessions.values():
        if image_id in session["image_ids"]:
            session["image_ids"].remove(image_id)

    img.delete_instance()
    return {"ok": True}


@app.post("/api/upload")
async def upload_images(
    session_id: str | None = Query(None),
    files: list[UploadFile] = File(...),
):
    # Get or create session
    if session_id and session_id in upload_sessions:
        session = upload_sessions[session_id]
    else:
        session_id = str(uuid.uuid4())
        session = {"author": generate_author_name(), "image_ids": []}
        upload_sessions[session_id] = session

    created = []
    for file in files:
        ext = os.path.splitext(file.filename or "img.jpg")[1] or ".jpg"
        filename = f"{uuid.uuid4().hex}{ext}"
        filepath = os.path.join(UPLOAD_DIR, filename)

        content = await file.read()
        with open(filepath, "wb") as f:
            f.write(content)

        img = Image.create(
            author=session["author"],
            path=filename,
        )
        session["image_ids"].append(img.id)
        created.append(image_to_dict(img))

    return {
        "session_id": session_id,
        "author": session["author"],
        "images": created,
    }


@app.get("/api/sessions/{session_id}", response_model=SessionOut)
def get_session(session_id: str):
    if session_id not in upload_sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    s = upload_sessions[session_id]
    return {"session_id": session_id, "author": s["author"], "image_ids": s["image_ids"]}


class RenameRequest(BaseModel):
    author: str


@app.put("/api/sessions/{session_id}/rename")
def rename_session(session_id: str, data: RenameRequest):
    if session_id not in upload_sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    session = upload_sessions[session_id]
    old_author = session["author"]
    session["author"] = data.author
    # Update all images from this session
    Image.update(author=data.author).where(
        Image.id.in_(session["image_ids"])
    ).execute()
    return {"session_id": session_id, "author": data.author}


@app.post("/api/sessions/{session_id}/randomize-name")
def randomize_session_name(session_id: str):
    if session_id not in upload_sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    session = upload_sessions[session_id]
    new_name = generate_author_name()
    session["author"] = new_name
    Image.update(author=new_name).where(
        Image.id.in_(session["image_ids"])
    ).execute()
    return {"session_id": session_id, "author": new_name}


@app.get("/api/random-name")
def get_random_name():
    """Get a random name without needing a session (for pre-session display)."""
    return {"name": generate_author_name()}


@app.get("/api/uploads/{filename}")
def serve_upload(filename: str):
    filepath = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(filepath)


@app.get("/api/dates")
def list_dates_with_images():
    """Return all dates that have at least one placed image."""
    query = (
        Image.select(Image.date)
        .where(Image.date.is_null(False))
        .where(Image.location_x.is_null(False))
        .distinct()
        .order_by(Image.date)
    )
    return [img.date.isoformat() for img in query if img.date]
