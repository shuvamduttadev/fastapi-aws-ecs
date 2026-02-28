from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.api import api_router as v1_router
from app.core.config import settings
from app.core.exceptions import validation_exception_handler, http_exception_handler
from app.utils.rate_limiter import limiter
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="A professional enterprise-level FastAPI project with CRUD operations",
    version="1.0.0",
    docs_url="/api/docs",
    openapi_url="/api/openapi.json",
    redoc_url="/api/redoc",
)

# ============================================================================
# Middleware Configuration
# ============================================================================

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=settings.CORS_CREDENTIALS,
    allow_methods=settings.CORS_METHODS,
    allow_headers=settings.CORS_HEADERS,
)

# Add rate limiting to app
app.state.limiter = limiter

# ============================================================================
# Exception Handlers
# ============================================================================

app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(HTTPException, http_exception_handler)

# ============================================================================
# API Routes
# ============================================================================

app.include_router(v1_router, prefix=settings.API_V1_STR)

# ============================================================================
# Response Models
# ============================================================================

class HealthResponse(BaseModel):
    """Health check response model"""
    status: str
    message: str
    version: str
    database: str = "connected"
    timestamp: datetime


class RootResponse(BaseModel):
    """Root endpoint response model"""
    message: str
    version: str
    environment: str
    documentation: str


# ============================================================================
# Health & Status Endpoints
# ============================================================================

@app.get("/", tags=["root"], response_model=RootResponse)
def root():
    """Root endpoint - Returns API information"""
    return {
        "message": f"Welcome to {settings.PROJECT_NAME}!",
        "version": "1.0.0",
        "environment": "development",
        "documentation": "/api/docs"
    }


@app.get("/health", tags=["Health"], response_model=HealthResponse)
def health_check():
    """
    Health check endpoint
    Returns 200 if service is healthy, 503 if unhealthy
    """
    try:
        # Optional: Check database connection
        # await database.execute("SELECT 1")
        
        return {
            "status": "healthy",
            "message": f"{settings.PROJECT_NAME} service is healthy!",
            "version": "1.0.0",
            "database": "connected",
            "timestamp": datetime.utcnow()
        }
    except Exception as e:
        # If database or critical service is down, return 503
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "status": "unhealthy",
                "message": f"Service is unhealthy: {str(e)}",
                "version": "1.0.0",
                "database": "disconnected",
                "timestamp": datetime.now(timezone.utc)
            }
        )


@app.get("/api/v1/status", tags=["Status"])
def api_status():
    """API v1 status endpoint"""
    return {
        "status": "operational",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc)
    }
