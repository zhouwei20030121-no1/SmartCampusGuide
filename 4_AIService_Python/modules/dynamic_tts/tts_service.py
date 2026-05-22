class TTSService:

    async def synthesize(self, text: str, voice: str = "default") -> dict:
        # TODO: 对接阿里云/百度 TTS SDK
        return {"audio_url": "", "duration": 0, "text": text}

    async def generate_script(self, spot_name: str, style: str = "standard") -> str:
        # TODO: 调用 LLM 动态生成景点讲解文案
        return f"欢迎来到{spot_name}，这里是西南大学最受欢迎的景点之一..."
