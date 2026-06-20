import os
from dotenv import load_dotenv

load_dotenv()

DEFAULT_DASHSCOPE_API_KEY = "sk-ws-H.RPIHMML.qwHX.MEUCIQC5elR9dl9vwW0nmoMQPL2WBECatb6FRkJ51l9x02p9JgIgQly6TpqRH0MprRxvZoP6Ggx8R3CvZmJtexmxgQ3YxQk"


class Settings:
    PORT: int = int(os.getenv("AI_PORT", 5000))
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    OPENAI_BASE_URL: str = os.getenv("OPENAI_BASE_URL", "https://api.deepseek.com")
    OPENAI_MODEL: str = os.getenv("OPENAI_MODEL", "deepseek-chat")
    VISION_MODEL: str = os.getenv("VISION_MODEL", "qwen-vl-max")
    VISION_API_KEY: str = os.getenv("VISION_API_KEY", os.getenv("OPENAI_API_KEY", ""))
    VISION_BASE_URL: str = os.getenv("VISION_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1")
    OPENAI_TEMPERATURE: float = float(os.getenv("OPENAI_TEMPERATURE", 0.3))
    OPENAI_MAX_TOKENS: int = int(os.getenv("OPENAI_MAX_TOKENS", 500))
    VECTOR_SEARCH_ENABLED: bool = os.getenv("VECTOR_SEARCH_ENABLED", "true").lower() == "true"
    EMBEDDING_MODEL: str = os.getenv("EMBEDDING_MODEL", "BAAI/bge-small-zh-v1.5")
    CHROMA_PERSIST_DIR: str = os.getenv("CHROMA_PERSIST_DIR", "./chroma_db")
    CHROMA_COLLECTION: str = os.getenv("CHROMA_COLLECTION", "smart_campus_knowledge")
    TTS_ACCESS_KEY: str = os.getenv("TTS_ACCESS_KEY", "")
    TTS_SECRET_KEY: str = os.getenv("TTS_SECRET_KEY", "")
    DASHSCOPE_API_KEY: str = os.getenv(
        "DASHSCOPE_API_KEY",
        os.getenv("TTS_API_KEY", DEFAULT_DASHSCOPE_API_KEY),
    )
    TTS_MODEL: str = os.getenv("TTS_MODEL", "qwen-tts-latest")
    TTS_BASE_URL: str = os.getenv(
        "TTS_BASE_URL",
        "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation",
    )


settings = Settings()
