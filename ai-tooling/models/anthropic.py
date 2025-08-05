import requests

class Model:
    def __init__(self, endpoint, api_key=None):
        self.endpoint = endpoint
        self.api_key = api_key

    def generate(self, prompt, max_tokens=256, model="claude-3-opus-20240229"):
        headers = {
            "x-api-key": self.api_key if self.api_key else "",
            "Content-Type": "application/json"
        }
        payload = {
            "model": model,
            "max_tokens": max_tokens,
            "messages": [
                {"role": "user", "content": prompt}
            ]
        }
        response = requests.post(self.endpoint, json=payload, headers=headers)
        response.raise_for_status()
        data = response.json()
        # Anthropic API returns completions in a nested structure
        return data.get("choices", [{}])[0].get("message", {}).get("content", "")
