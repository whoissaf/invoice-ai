from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = 'users'
    
    id = Column(UUID(as_uuid=True), primary_key=True, server_default='gen_random_uuid()')
    email = Column(String(255), unique=True, nullable=False)
    password_hash = Column(String(255))
    full_name = Column(String(255), nullable=False)
    phone = Column(String(20))

    @classmethod
    def get(cls, session, username):
        return session.query(cls).filter(cls.email == username).first()
    role = Column(String(20), nullable=False)  # ADMIN, BORROWER, INVESTOR, UNDERWRITER
    status = Column(String(20), default='PENDING')  # PENDING, ACTIVE, SUSPENDED
    email_verified = Column(Boolean, default=False)
    kyc_status = Column(String(20), default='NOT_STARTED')
    created_at = Column(DateTime, server_default='now()')
    updated_at = Column(DateTime, server_default='now()')

class Business(Base):
    __tablename__ = 'businesses'
    
    id = Column(UUID(as_uuid=True), primary_key=True, server_default='gen_random_uuid()')
    user_id = Column(UUID(as_uuid=True), ForeignKey('users.id'))
    company_name = Column(String(255), nullable=False)
    npwp = Column(String(20), unique=True, nullable=False)
    industry = Column(String(100))
    address = Column(Text)
    city = Column(String(100))
    province = Column(String(100))
    postal_code = Column(String(10))
    bank_account_name = Column(String(255))
    bank_account_number = Column(String(50))
    bank_name = Column(String(100))
    kyb_status = Column(String(20), default='NOT_STARTED')
    risk_rating = Column(String(5))
    created_at = Column(DateTime, server_default='now()')

class Invoice(Base):
    __tablename__ = 'invoices'
    
    id = Column(UUID(as_uuid=True), primary_key=True, server_default='gen_random_uuid()')
    invoice_number = Column(String(100), nullable=False)
    borrower_id = Column(UUID(as_uuid=True), ForeignKey('businesses.id'))
    debtor_id = Column(UUID(as_uuid=True), ForeignKey('debtors.id'))
    face_value = Column(Float, nullable=False)
    currency = Column(String(3), default='IDR')
    issue_date = Column(DateTime, nullable=False)
    due_date = Column(DateTime, nullable=False)
    status = Column(String(20), default='DRAFT')  # DRAFT, UPLOADED, VERIFIED, TOKENIZED, LISTED, FUNDED, REPAID, DEFAULTED
    ocr_confidence = Column(Float)
    nft_token_id = Column(Integer)
    nft_tx_hash = Column(String(66))
    credit_score = Column(Float)
    risk_grade = Column(String(5))
    advance_rate = Column(Float)
    factoring_fee = Column(Float)
    reserve_amount = Column(Float)
    created_at = Column(DateTime, server_default='now()')
    updated_at = Column(DateTime, server_default='now()')

class Debtor(Base):
    __tablename__ = 'debtors'
    
    id = Column(UUID(as_uuid=True), primary_key=True, server_default='gen_random_uuid()')
    company_name = Column(String(255), nullable=False)
    npwp = Column(String(20), unique=True)
    contact_name = Column(String(255))
    contact_email = Column(String(255))
    contact_phone = Column(String(20))
    address = Column(Text)
    industry = Column(String(100))
    credit_score = Column(Float)
    risk_grade = Column(String(5))
    total_invoices = Column(Integer, default=0)
    on_time_payments = Column(Integer, default=0)
    late_payments = Column(Integer, default=0)
    avg_days_late = Column(Float)
    created_at = Column(DateTime, server_default='now()')

class Listing(Base):
    __tablename__ = 'listings'
    
    id = Column(UUID(as_uuid=True), primary_key=True, server_default='gen_random_uuid()')
    invoice_id = Column(UUID(as_uuid=True), ForeignKey('invoices.id'), unique=True)
    borrower_id = Column(UUID(as_uuid=True), ForeignKey('businesses.id'))
    target_amount = Column(Float, nullable=False)
    min_yield = Column(Float)
    auction_start = Column(DateTime, nullable=False)
    auction_end = Column(DateTime, nullable=False)
    status = Column(String(20), default='ACTIVE')  # ACTIVE, CLOSED
    winning_bid_id = Column(UUID(as_uuid=True))
    created_at = Column(DateTime, server_default='now()')

class Bid(Base):
    __tablename__ = 'bids'
    
    id = Column(UUID(as_uuid=True), primary_key=True, server_default='gen_random_uuid()')
    listing_id = Column(UUID(as_uuid=True), ForeignKey('listings.id'))
    investor_id = Column(UUID(as_uuid=True), ForeignKey('users.id'))
    amount = Column(Float, nullable=False)
    yield_rate = Column(Float, nullable=False)
    status = Column(String(20), default='ACTIVE')  # ACTIVE, WON, LOST
    escrow_tx_hash = Column(String(66))
    placed_at = Column(DateTime, server_default='now()')

class Loan(Base):
    __tablename__ = 'loans'
    
    id = Column(UUID(as_uuid=True), primary_key=True, server_default='gen_random_uuid()')
    listing_id = Column(UUID(as_uuid=True), ForeignKey('listings.id'))
    invoice_id = Column(UUID(as_uuid=True), ForeignKey('invoices.id'))
    borrower_id = Column(UUID(as_uuid=True), ForeignKey('businesses.id'))
    investor_id = Column(UUID(as_uuid=True), ForeignKey('users.id'))
    principal_amount = Column(Float, nullable=False)
    yield_rate = Column(Float, nullable=False)
    total_repayment = Column(Float, nullable=False)
    disbursed_at = Column(DateTime)
    due_date = Column(DateTime, nullable=False)
    status = Column(String(20), default='ACTIVE')  # ACTIVE, REPAID, DEFAULTED
    vault_address = Column(String(42))
    created_at = Column(DateTime, server_default='now()')
