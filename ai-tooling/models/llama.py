import requests

class Model:
    def __init__(self, endpoint):
        self.endpoint = endpoint

    def generate(self, prompt, **kwargs):
        """
        Sends a prompt to a local Llama server and returns the generated text.
        Assumes the server accepts POST requests with JSON: {"prompt": "..."}
        """
        payload = {"prompt": prompt}
        payload.update(kwargs)
        try:
            response = requests.post(self.endpoint, json=payload, timeout=30)
            response.raise_for_status()
            data = response.json()
            # Adapt to your server's response format
            return data.get("text") or data.get("generated") or str(data)
        except Exception as e:
            return f"[Llama Error] {e}"