from fastapi import FastAPI, HTTPException, status
from app.api.v1.api import api_router as v1_router
from app.core.exceptions import validation_exception_handler, http_exception_handler
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel

app = FastAPI(
    title="FastAPI Project",
    description="A sample FastAPI project with a structured layout.",
    version="1.0.0",
)

class HealthResponse(BaseModel):
    status: str
    message: str
    version: str
    database: str = "connected"

app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(HTTPException, http_exception_handler)
app.include_router(v1_router, prefix="/api/v1")

@app.get("/", tags=["root"])
async def root():
    return {
        "message": "Welcome to the FastAPI Project!",
        "version": "1.0.0",
    }


@app.get("/health", tags=["Health"], response_model=HealthResponse)
async def health_check():
    """
    Health check endpoint
    Returns 200 if service is healthy, 503 if unhealthy
    """
    try:
        # Optional: Check database connection
        # await database.execute("SELECT 1")
        
        return {
            "status": "healthy",
            "message": "FastAPI service is healthy!",
            "version": "1.0.0",
            "database": "connected"
        }
    except Exception as e:
        # If database or critical service is down, return 503
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "status": "unhealthy",
                "message": f"Service is unhealthy: {str(e)}",
                "version": "1.0.0",
                "database": "disconnected"
            }
        )