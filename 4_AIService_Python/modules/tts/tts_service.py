import os
import uuid
import httpx
from config import settings


class TTSService:
    """TTS 语音合成与 AI 文案生成服务"""

    async def generate_script(self, spot_name: str, description: str, language: str = "zh") -> str:
        """调用 LLM 生成讲解文案"""
        prompt = self._build_prompt(spot_name, description, language)
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                f"{settings.OPENAI_BASE_URL}/chat/completions",
                headers={"Authorization": f"Bearer {settings.OPENAI_API_KEY}"},
                json={
                    "model": "gpt-3.5-turbo",
                    "messages": [
                        {"role": "system", "content": "你是西南大学的校园导游，请用生动有趣的语言讲解校园景点。"},
                        {"role": "user", "content": prompt},
                    ],
                    "max_tokens": 500,
                },
            )
            data = resp.json()
            return data["choices"][0]["message"]["content"]

    async def synthesize(self, text: str, language: str = "zh") -> dict:
        """TTS 语音合成，返回音频文件路径"""
        audio_dir = os.path.join(os.path.dirname(__file__), "..", "..", "audio_output")
        os.makedirs(audio_dir, exist_ok=True)
        filename = f"tts_{uuid.uuid4().hex[:8]}.mp3"
        filepath = os.path.join(audio_dir, filename)

        # 阿里云 / 讯飞 TTS API 调用（TODO: 替换为真实 API）
        # 当前返回占位文件路径
        with open(filepath, "wb") as f:
            f.write(b"\x00" * 1024)

        return {
            "filename": filename,
            "filepath": filepath,
            "text": text,
            "language": language,
        }

    def _build_prompt(self, spot_name: str, description: str, language: str) -> str:
        lang_map = {"zh": "中文", "en": "English", "ja": "日本語"}
        lang_name = lang_map.get(language, "中文")
        return f"请用{lang_name}为以下校园景点撰写一段约200字的导游讲解词。\n景点名称：{spot_name}\n景点简介：{description}"


tts_service = TTSService()
