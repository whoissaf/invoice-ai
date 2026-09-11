from pydantic import BaseModel, EmailStr, Field, HttpUrl
from datetime import date, datetime
from typing import Optional, List
from enum import Enum

class UserRole(str, Enum):
    ADMIN = "ADMIN"
    BORROWER = "BORROWER"
    INVESTOR = "INVESTOR"
    UNDERWRITER = "UNDERWRITER"

class UserBase(BaseModel):
    email: EmailStr
    full_name: str = Field(..., min_length=2, max_length=255)
    phone: str = Field(..., regex=r"^\+?[0-9]{8,15}$")
    role: UserRole

class UserCreate(UserBase):
    password: str = Field(..., min_length=8, max_length=128)

class UserResponse(UserBase):
    id: str
    kyc_status: str
    created_at: datetime

class KYCDocument(BaseModel):
    document_type: str
    file_url: HttpUrl
    file_hash: str

class KYCSchema(BaseModel):
    ktp_number: str = Field(..., min_length=16, max_length=16)
    selfie_url: HttpUrl
    documents: List[KYCDocument]

class BusinessBase(BaseModel):
    company_name: str = Field(..., min_length=2, max_length=255)
    npwp: str = Field(..., min_length=15, max_length=20)
    industry: str
    address: str
    city: str
    province: str
    postal_code: str
    bank_account_name: str
    bank_account_number: str
    bank_name: str

class InvoiceBase(BaseModel):
    invoice_number: str
    debtor_name: str
    debtor_npwp: Optional[str]
    face_value: float = Field(..., gt=0)
    currency: str = Field(default="IDR", min_length=3, max_length=3)
    issue_date: date
    due_date: date

class InvoiceCreate(InvoiceBase):
    documents: List[HttpUrl]

class InvoiceResponse(InvoiceBase):
    id: str
    status: str
    ocr_confidence: Optional[float]
    nft_token_id: Optional[int]
    nft_tx_hash: Optional[str]
    credit_score: Optional[float]
    risk_grade: Optional[str]
    created_at: datetime

class BidBase(BaseModel):
    amount: float = Field(..., gt=0)
    yield_rate: float = Field(..., gt=0)

class BidResponse(BidBase):
    id: str
    investor_id: str
    status: str
    placed_at: datetime

class LoanBase(BaseModel):
    principal_amount: float = Field(..., gt=0)
    yield_rate: float = Field(..., gt=0)
    total_repayment: float = Field(..., gt=0)
    due_date: date

class LoanResponse(LoanBase):
    id: str
    borrower_id: str
    investor_id: str
    status: str
    disbursed_at: Optional[datetime]
    created_at: datetime

class CreditScoreInput(BaseModel):
    invoice_id: str
    debtor_name: str
    debtor_npwp: Optional[str]
    face_value: float
    due_date: date
    borrower_history: dict
    debtor_history: dict
    industry: str
    macro_indicators: Optional[dict] = {}

class CreditScoreOutput(BaseModel):
    invoice_id: str
    risk_grade: str
    risk_score: float
    default_probability: float
    recommended_yield: float
    recommended_advance_rate: float
    factors: List[dict]
    model_version: str

class NotificationBase(BaseModel):
    type: str
    title: str
    message: str

class NotificationResponse(NotificationBase):
    id: str
    is_read: bool
    created_at: datetime
