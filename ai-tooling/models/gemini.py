class GeminiModel:
    """
    Wrapper for Google Gemini API.
    """

    def __init__(self, endpoint, api_key=None):
        self.endpoint = endpoint
        self.api_key = api_key

    def generate(self, prompt, **kwargs):
        """
        Generate text using Gemini API.
        """
        import requests

        headers = {
            "Content-Type": "application/json",
        }
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": prompt}
                    ]
                }
            ]
        }
        payload.update(kwargs)

        response = requests.post(self.endpoint, json=payload, headers=headers)
        response.raise_for_status()
        data = response.json()

        # Gemini returns candidates in 'candidates' key
        if "candidates" in data and data["candidates"]:
            return data["candidates"][0]["content"]["parts"][0]["text"]
        # Fallback for other possible response formats
        return data

# Usage example:
# model = GeminiModel("https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent", api_key="YOUR_API_KEY")
# result = model.generate("Hello, Gemini!")