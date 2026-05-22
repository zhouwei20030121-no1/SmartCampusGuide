from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from modules.dynamic_tts.tts_router import router as tts_router
from modules.agent_vision.vision_router import router as vision_router

app = FastAPI(title="智慧校园导览 - AI 微服务", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(tts_router, prefix="/api/tts", tags=["TTS语音合成"])
app.include_router(vision_router, prefix="/api/vision", tags=["AI视觉与RAG"])


@app.get("/")
def root():
    return {"service": "SmartCampusGuide AI", "version": "1.0.0"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=settings.PORT, reload=True)
