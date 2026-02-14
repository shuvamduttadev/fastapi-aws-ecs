from fastapi import APIRouter, Depends
from fastapi.encoders import jsonable_encoder
from typing import Annotated

router = APIRouter()

async def common_parameters(q: str | None = None, skip: int = 0, limit: int = 100):
    return {"q": q}

@router.get("/")
async def get_users():
    return jsonable_encoder(["shuvam", "dutta"])

@router.get("/{user_id}")
async def get_user(user_id: int):
    return {"user_id": user_id}

@router.get("/search/")
async def search_users(commons: dict = Depends(common_parameters)):
    return commons


fake_items_db = [{"item_name": "Foo"}, {"item_name": "Bar"}, {"item_name": "Baz"}]


class CommonQueryParams:
    def __init__(self, q: str | None = None, skip: int = 0, limit: int = 100):
        self.q = q
        self.skip = skip
        self.limit = limit


@router.get("/items/")
async def read_items(commons: Annotated[CommonQueryParams, Depends(CommonQueryParams)]):
    response = {}
    if commons.q:
        response.update({"q": commons.q})
    items = fake_items_db[commons.skip : commons.skip + commons.limit]
    response.update({"items": items})
    return response