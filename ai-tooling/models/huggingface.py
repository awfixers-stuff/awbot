class Model:
    def __init__(self, endpoint, api_key=None, model_id=None):
        self.endpoint = endpoint
        self.api_key = api_key
        self.model_id = model_id

    def generate(self, prompt, **kwargs):
        import requests

        headers = {
            "Authorization": f"Bearer {self.api_key}" if self.api_key else "",
            "Content-Type": "application/json"
        }
        payload = {
            "inputs": prompt,
            "parameters": kwargs,
            "options": {"wait_for_model": True}
        }
        url = self.endpoint
        if self.model_id:
            url = f"{self.endpoint}/models/{self.model_id}"

        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
        # HuggingFace Inference API returns a list of generated texts
        if isinstance(data, list) and len(data) > 0 and "generated_text" in data[0]:
            return data[0]["generated_text"]
        # Some endpoints may return 'text' or other keys
        if "text" in data:
            return data["text"]
        return data