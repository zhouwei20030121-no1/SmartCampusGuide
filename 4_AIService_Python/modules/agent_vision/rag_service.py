class RAGService:

    def __init__(self):
        # TODO: 初始化 LangChain RAG 知识库（Chroma 向量数据库）
        pass

    async def chat(self, question: str, user_id: str = "") -> str:
        # TODO: 调用 LLM + RAG 多轮对话
        return f"关于「{question}」的问题，让我为您介绍一下..."

    async def recognize_image(self, image_url: str) -> dict:
        # TODO: 调用视觉模型识别校园建筑/植物
        return {
            "name": "未知建筑",
            "description": "正在学习中...",
            "confidence": 0.0,
        }
