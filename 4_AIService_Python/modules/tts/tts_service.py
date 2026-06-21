import os
import logging
import hashlib
import json
import httpx
from config import settings

logger = logging.getLogger("smart_campus.tts")


class TTSService:
    """TTS 语音合成与 AI 文案生成服务"""

    VOICE_PROFILES = {
        "gentle_guide": {
            "voice_id": "Cherry",
            "name": "芊悦",
            "label": "阳光女声",
            "gender": "female",
        },
        "young_female": {
            "voice_id": "Serena",
            "name": "苏瑶",
            "label": "温柔女声",
            "gender": "female",
        },
        "young_male": {
            "voice_id": "Ethan",
            "name": "晨煦",
            "label": "朝气男声",
            "gender": "male",
        },
        "calm_male": {
            "voice_id": "Dylan",
            "name": "北京-晓东",
            "label": "京腔男声",
            "gender": "male",
        },
    }

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

    async def synthesize(
        self,
        text: str,
        language: str = "zh",
        voice: str = "gentle_guide",
        rate: float = 1.0,
    ) -> dict:
        """调用百炼 Qwen-TTS/CosyVoice 合成语音，并缓存为本地音频文件。"""
        content = text.strip()
        if not content:
            raise ValueError("合成文本不能为空")
        if not settings.DASHSCOPE_API_KEY:
            raise RuntimeError("未配置 DASHSCOPE_API_KEY/TTS_API_KEY，无法调用云端语音合成")

        profile_key = voice if voice in self.VOICE_PROFILES else "gentle_guide"
        profile = self.VOICE_PROFILES[profile_key]
        speech_rate = max(0.5, min(2.0, float(rate or 1.0)))
        language_hint = self._language_hint(language)
        audio_dir = os.path.join(os.path.dirname(__file__), "..", "..", "audio_output")
        os.makedirs(audio_dir, exist_ok=True)
        cache_key = self._cache_key(content, language_hint, profile_key, speech_rate)
        cached = self._find_cached_audio(audio_dir, cache_key)
        if cached:
            filename, filepath, media_type = cached
            return self._build_result(
                filename=filename,
                filepath=filepath,
                text=text,
                language=language,
                profile_key=profile_key,
                profile=profile,
                speech_rate=speech_rate,
                request_id=None,
                expires_at=None,
                usage={},
                media_type=media_type,
                cached=True,
            )

        payload = self._build_tts_payload(
            content=content,
            voice_id=profile["voice_id"],
            language=language,
            language_hint=language_hint,
            speech_rate=speech_rate,
        )
        async with httpx.AsyncClient(timeout=httpx.Timeout(60.0, connect=15.0)) as client:
            response = await client.post(
                settings.TTS_BASE_URL,
                headers={
                    "Authorization": f"Bearer {settings.DASHSCOPE_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            if response.status_code >= 400:
                raise RuntimeError(
                    f"云端语音合成失败：HTTP {response.status_code} {response.text[:300]}"
                )
            data = response.json()
            audio = data.get("output", {}).get("audio", {})
            remote_url = audio.get("url")
            if not remote_url:
                raise RuntimeError(f"云端语音未返回音频 URL：{str(data)[:300]}")

            audio_response = await client.get(remote_url)
            if audio_response.status_code >= 400 or not audio_response.content:
                raise RuntimeError(f"音频下载失败：HTTP {audio_response.status_code}")
            ext, media_type = self._detect_audio_format(audio_response.content)
            filename = f"tts_{cache_key}.{ext}"
            filepath = os.path.join(audio_dir, filename)
            with open(filepath, "wb") as f:
                f.write(audio_response.content)

        usage = data.get("usage", {})
        logger.warning(
            "tts_synthesized model=%s voice=%s voice_id=%s voice_name=%s rate=%.2f language=%s file=%s total_tokens=%s input_tokens=%s output_tokens=%s characters=%s request_id=%s",
            settings.TTS_MODEL,
            profile_key,
            profile["voice_id"],
            profile["name"],
            speech_rate,
            language_hint,
            filename,
            usage.get("total_tokens"),
            usage.get("input_tokens"),
            usage.get("output_tokens"),
            usage.get("characters"),
            data.get("request_id"),
        )

        return self._build_result(
            filename=filename,
            filepath=filepath,
            text=text,
            language=language,
            profile_key=profile_key,
            profile=profile,
            speech_rate=speech_rate,
            request_id=data.get("request_id"),
            expires_at=audio.get("expires_at"),
            usage=usage,
            media_type=media_type,
            cached=False,
        )

    def _cache_key(
        self,
        content: str,
        language_hint: str,
        profile_key: str,
        speech_rate: float,
    ) -> str:
        raw = json.dumps(
            {
                "model": settings.TTS_MODEL,
                "text": content,
                "language": language_hint,
                "voice": profile_key,
                "rate": round(speech_rate, 3),
            },
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]

    def _find_cached_audio(self, audio_dir: str, cache_key: str) -> tuple[str, str, str] | None:
        for ext, media_type in (("wav", "audio/wav"), ("mp3", "audio/mpeg")):
            filename = f"tts_{cache_key}.{ext}"
            filepath = os.path.join(audio_dir, filename)
            if os.path.exists(filepath) and os.path.getsize(filepath) > 44:
                return filename, filepath, media_type
        return None

    def _detect_audio_format(self, content: bytes) -> tuple[str, str]:
        if content.startswith(b"RIFF") and content[8:12] == b"WAVE":
            return "wav", "audio/wav"
        if content.startswith(b"ID3") or content[:2] in (b"\xff\xfb", b"\xff\xf3", b"\xff\xf2"):
            return "mp3", "audio/mpeg"
        return "bin", "application/octet-stream"

    def _build_result(
        self,
        *,
        filename: str,
        filepath: str,
        text: str,
        language: str,
        profile_key: str,
        profile: dict,
        speech_rate: float,
        request_id: str | None,
        expires_at: str | None,
        usage: dict,
        media_type: str,
        cached: bool,
    ) -> dict:
        return {
            "filename": filename,
            "filepath": filepath,
            "url": f"/api/tts/audio/{filename}",
            "text": text,
            "language": language,
            "voice": profile_key,
            "voice_id": profile["voice_id"],
            "voice_name": profile["name"],
            "voice_label": profile["label"],
            "voice_gender": profile["gender"],
            "model": settings.TTS_MODEL,
            "rate": speech_rate,
            "request_id": request_id,
            "expires_at": expires_at,
            "usage": usage,
            "characters": usage.get("characters"),
            "input_tokens": usage.get("input_tokens"),
            "output_tokens": usage.get("output_tokens"),
            "total_tokens": usage.get("total_tokens"),
            "media_type": media_type,
            "cached": cached,
        }

    def list_voices(self) -> dict:
        return self.VOICE_PROFILES

    def _build_prompt(self, spot_name: str, description: str, language: str) -> str:
        lang_map = {"zh": "中文", "en": "English", "ja": "日本語"}
        lang_name = lang_map.get(language, "中文")
        return f"请用{lang_name}为以下校园景点撰写一段约200字的导游讲解词。\n景点名称：{spot_name}\n景点简介：{description}"

    def _language_hint(self, language: str) -> str:
        return {
            "zh": "zh",
            "en": "en",
            "ja": "ja",
            "fr": "fr",
            "ko": "ko",
        }.get(language, "zh")

    def _language_type(self, language: str) -> str:
        return {
            "zh": "Chinese",
            "en": "English",
            "ja": "Japanese",
            "fr": "French",
            "ko": "Korean",
        }.get(language, "Chinese")

    def _build_tts_payload(
        self,
        content: str,
        voice_id: str,
        language: str,
        language_hint: str,
        speech_rate: float,
    ) -> dict:
        if settings.TTS_MODEL.startswith("cosyvoice"):
            return {
                "model": settings.TTS_MODEL,
                "input": {
                    "text": content,
                    "voice": voice_id,
                    "format": "mp3",
                    "sample_rate": 24000,
                    "volume": 55,
                    "rate": speech_rate,
                    "language_hints": [language_hint],
                },
            }

        return {
            "model": settings.TTS_MODEL,
            "input": {
                "text": content,
                "voice": voice_id,
                "language_type": self._language_type(language),
            },
        }


tts_service = TTSService()
