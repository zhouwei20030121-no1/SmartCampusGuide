from typing import Any

from pydantic import BaseModel


class ApiResponse(BaseModel):
    code: int = 200
    message: str = "success"
    data: Any = None

    @staticmethod
    def ok(data: Any = None) -> dict:
        return {"code": 200, "message": "success", "data": data}

    @staticmethod
    def fail(message: str, code: int = 500) -> dict:
        return {"code": code, "message": message, "data": None}
