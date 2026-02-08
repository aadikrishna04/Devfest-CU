import pathlib
import sys

import modal

app = modal.App(name="first-aid-coach")

image = modal.Image.debian_slim(python_version="3.11").pip_install(
    "fastapi",
    "uvicorn",
    "websockets>=12.0",
    "openai>=1.0",
    "dedalus_labs",
)

# Copy all backend .py files into the image directly
backend_dir = pathlib.Path(__file__).parent
for py_file in backend_dir.glob("*.py"):
    if py_file.name != "app.py":
        image = image.add_local_file(str(py_file), f"/root/{py_file.name}")


@app.function(
    image=image,
    secrets=[modal.Secret.from_dotenv(__file__)],
    timeout=3600,
)
@modal.asgi_app()
def create_app():
    from fastapi import FastAPI, WebSocket, WebSocketDisconnect

    sys.path.insert(0, "/root")

    from orchestrator import Orchestrator

    web_app = FastAPI(title="First-Aid Coach Backend")

    @web_app.get("/health")
    async def health():
        return {"status": "ok"}

    @web_app.websocket("/ws")
    async def websocket_endpoint(ws: WebSocket):
        await ws.accept()
        print("[Gateway] iOS client connected")
        orch = Orchestrator(ws)
        try:
            await orch.run()
        except WebSocketDisconnect:
            print("[Gateway] iOS client disconnected")
        except Exception as e:
            print(f"[Gateway] Error: {e}")
        finally:
            await orch.shutdown()
            print("[Gateway] Session cleaned up")

    return web_app
