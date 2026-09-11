from fastapi import APIRouter, Depends
from typing import List

router = APIRouter()

@router.get("/api/v1/")
async def root():
    return {"message": "Welcome to InvoiceFlow API"}
