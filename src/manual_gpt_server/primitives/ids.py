# primitives/ids.py
import uuid
def new_completion_id() -> str:
    return f"chatcmpl-{uuid.uuid4().hex}"