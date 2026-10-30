import os
import logging
import uuid
import base64
import binascii

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from openai import AsyncOpenAI, OpenAIError
from pydantic import BaseModel, Field

from services.agent_router import AgentRouter
from services.collaboration_service import CollaborationService
from memory.conversation_memory import ConversationMemory
from agents.vision_agent import vision_agent


# ==========================================
# OMEGA AI 4.0 - CONFIGURATION
# ==========================================

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("omega_ai")

app = FastAPI(
    title="OMEGA AI",
    version="4.0.0"
)

client = AsyncOpenAI(
    api_key=os.getenv("OPENAI_API_KEY")
)

router = AgentRouter(client)
collaboration = CollaborationService(client)
memory = ConversationMemory()


# ==========================================
# REQUEST / RESPONSE MODELS
# ==========================================

class ChatRequest(BaseModel):
    message: str = Field(
        min_length=1,
        max_length=10000
    )
    conversation_id: str | None = None
    collaboration: bool = False


class ChatResponse(BaseModel):
    response: str
    agent: str
    agent_key: str
    conversation_id: str
    collaborators: list[str] = Field(default_factory=list)


class VisionRequest(BaseModel):
    image_base64: str = Field(
        min_length=1,
        max_length=14_000_000
    )
    message: str = Field(
        default="Analizează această imagine.",
        max_length=10000
    )


class VisionResponse(BaseModel):
    response: str
    agent: str


# ==========================================
# HOME ENDPOINT
# ==========================================

@app.get("/")
async def home():
    return {
        "name": "OMEGA AI",
        "version": "4.0.0",
        "status": "online",
        "memory": True,
        "collaboration": True,
        "vision": True
    }


# ==========================================
# AVAILABLE AGENTS
# ==========================================

@app.get("/agents")
async def get_agents():
    return {
        "agents": [
            "Code Agent",
            "Research Agent",
            "Data Agent",
            "General Agent",
            "Vision Agent"
        ]
    }


# ==========================================
# CHAT ENDPOINT
# ==========================================

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):

    conversation_id = (
        request.conversation_id or str(uuid.uuid4())
    )

    history = memory.get_history(conversation_id)

    try:
        if request.collaboration:
            result = await collaboration.collaborate(
                request.message,
                history
            )
        else:
            result = await router.process(
                request.message,
                history=history
            )

        memory.save_message(
            conversation_id,
            "user",
            request.message
        )

        memory.save_message(
            conversation_id,
            "assistant",
            result["response"]
        )

        logger.info(
            "Selected agent: %s",
            result["agent"]
        )

        return ChatResponse(
            response=result["response"],
            agent=result["agent"],
            agent_key=result["agent_key"],
            conversation_id=conversation_id,
            collaborators=result.get("collaborators", [])
        )

    except OpenAIError:
        logger.exception("OpenAI request failed")

        raise HTTPException(
            status_code=502,
            detail="AI provider unavailable"
        )

    except (ValueError, KeyError):
        logger.exception("Invalid agent response")

        raise HTTPException(
            status_code=502,
            detail="Invalid AI response"
        )


# ==========================================
# VISION AI ENDPOINT
# ==========================================

@app.post("/vision", response_model=VisionResponse)
async def analyze_image(request: VisionRequest):

    try:
        # Decode Base64 image
        image_bytes = base64.b64decode(
            request.image_base64,
            validate=True
        )

        # Maximum image size: 10 MB
        if len(image_bytes) > 10 * 1024 * 1024:
            raise HTTPException(
                status_code=413,
                detail="Imaginea depășește limita de 10 MB."
            )

        # Detect image format
        if image_bytes.startswith(b"\xff\xd8\xff"):
            mime_type = "image/jpeg"

        elif image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            mime_type = "image/png"

        elif (
            image_bytes.startswith(b"RIFF")
            and image_bytes[8:12] == b"WEBP"
        ):
            mime_type = "image/webp"

        else:
            raise HTTPException(
                status_code=400,
                detail="Format neacceptat. Folosește JPG, PNG sau WEBP."
            )

        # Send image to OpenAI Vision
        result = await client.responses.create(
            model=os.getenv(
                "OPENAI_MODEL",
                "gpt-4.1-mini"
            ),
            instructions=vision_agent.instructions,
            input=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "input_text",
                            "text": request.message
                        },
                        {
                            "type": "input_image",
                            "image_url": (
                                f"data:{mime_type};base64,"
                                f"{request.image_base64}"
                            )
                        }
                    ]
                }
            ]
        )

        logger.info(
            "Vision Agent processed an image"
        )

        return VisionResponse(
            response=result.output_text,
            agent="Vision Agent"
        )

    except (ValueError, binascii.Error):
        raise HTTPException(
            status_code=400,
            detail="Imagine Base64 invalidă."
        )

    except OpenAIError:
        logger.exception("Vision API failed")

        raise HTTPException(
            status_code=502,
            detail="Vision AI unavailable."
        )