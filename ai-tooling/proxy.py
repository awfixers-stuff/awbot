import yaml
import importlib
import os

class ModelProxy:
    """
    A proxy for routing requests to multiple AI models/providers.
    Supports dynamic loading of model wrappers from the models/ directory.
    """

    def __init__(self, config_path=None):
        if config_path is None:
            config_path = os.path.join(os.path.dirname(__file__), "config.yaml")
        with open(config_path) as f:
            self.config = yaml.safe_load(f)
        self.models = self._load_models()

    def _load_models(self):
        """
        Dynamically import model wrappers based on config.
        Each model type must have a corresponding module in models/ (e.g., models/openai.py).
        """
        models = {}
        for name, info in self.config.get("models", {}).items():
            module_path = f"awbot.ai-tooling.models.{info['type']}"
            try:
                module = importlib.import_module(module_path)
                models[name] = module.Model(info["endpoint"], info.get("api_key"), info.get("params", {}))
            except Exception as e:
                print(f"Error loading model '{name}' ({module_path}): {e}")
        return models

    def generate(self, prompt, model_name=None, **kwargs):
        """
        Generate text using the specified model.
        If model_name is None, uses the default model.
        Additional kwargs are passed to the model's generate method.
        """
        if not model_name:
            model_name = self.config.get("default_model")
        model = self.models.get(model_name)
        if not model:
            raise ValueError(f"Model '{model_name}' not found in proxy.")
        return model.generate(prompt, **kwargs)

    def classify(self, text, model_name=None, **kwargs):
        """
        Classify text using the specified model.
        """
        if not model_name:
            model_name = self.config.get("default_model")
        model = self.models.get(model_name)
        if not model or not hasattr(model, "classify"):
            raise ValueError(f"Model '{model_name}' does not support classification.")
        return model.classify(text, **kwargs)

    def list_models(self):
        """
        List available models.
        """
        return list(self.models.keys())