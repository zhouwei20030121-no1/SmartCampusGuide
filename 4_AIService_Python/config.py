import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    PORT: int = int(os.getenv("AI_PORT", 5000))
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    OPENAI_BASE_URL: str = os.getenv("OPENAI_BASE_URL", "")
    CHROMA_PERSIST_DIR: str = os.getenv("CHROMA_PERSIST_DIR", "./chroma_db")
    TTS_ACCESS_KEY: str = os.getenv("TTS_ACCESS_KEY", "")
    TTS_SECRET_KEY: str = os.getenv("TTS_SECRET_KEY", "")


settings = Settings()
