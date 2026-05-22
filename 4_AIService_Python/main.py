from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from modules.tts.tts_router import router as tts_router
from modules.rag.rag_router import router as rag_router
from modules.vision.vision_router import router as vision_router

app = FastAPI(title="智慧校园导览 - AI 微服务", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(tts_router, prefix="/api/tts", tags=["TTS语音合成"])
app.include_router(rag_router, prefix="/api/rag", tags=["RAG知识库"])
app.include_router(vision_router, prefix="/api/vision", tags=["AI视觉识别"])


@app.get("/")
def root():
    return {"service": "SmartCampusGuide AI", "version": "1.0.0"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=settings.PORT, reload=True)
