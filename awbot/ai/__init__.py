from awbot.ai_tooling.proxy import ModelProxy

# Initialize the proxy with default config
proxy = ModelProxy()

def generate_text(prompt, model=None, **kwargs):
    """
    Generate text using the specified model.
    :param prompt: The input prompt string.
    :param model: Optional model name. If None, uses default.
    :param kwargs: Additional arguments for model-specific options.
    :return: Generated text string.
    """
    return proxy.generate(prompt, model_name=model, **kwargs)

def classify_message(message, model=None, **kwargs):
    """
    Classify a message using the specified model.
    :param message: The input message string.
    :param model: Optional model name. If None, uses default.
    :param kwargs: Additional arguments for model-specific options.
    :return: Classification result.
    """
    return proxy.classify(message, model_name=model, **kwargs)

def embed_text(text, model=None, **kwargs):
    """
    Get text embeddings from the specified model.
    :param text: The input text string.
    :param model: Optional model name. If None, uses default.
    :param kwargs: Additional arguments for model-specific options.
    :return: Embedding vector/list.
    """
    return proxy.embed(text, model_name=model, **kwargs)

def available_models():
    """
    List all available models configured in the proxy.
    :return: List of model names.
    """
    return proxy.list_models()