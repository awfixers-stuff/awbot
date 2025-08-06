class Model:
    def __init__(self, endpoint, api_key=None):
        self.endpoint = endpoint
        self.api_key = api_key

    def generate(self, prompt, **kwargs):
        import requests

        headers = {
            "Authorization": f"Bearer {self.api_key}" if self.api_key else "",
            "Content-Type": "application/json"
        }
        payload = {
            "model": kwargs.get("model", "gpt-4"),
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": kwargs.get("max_tokens", 256),
            "temperature": kwargs.get("temperature", 0.7)
        }
        response = requests.post(self.endpoint, json=payload, headers=headers)
        response.raise_for_status()
        data = response.json()
        # OpenAI returns choices[0].message.content for chat models
        return data["choices"][0]["message"]["content"]