import discord
from discord.ext import commands
from discord import app_commands

from awbot.awbot.ai import generate_text, available_models

class AICommands(commands.Cog):
    """AI command handlers for both whitespace and app commands."""

    def __init__(self, bot):
        self.bot = bot

    # Whitespace command: !ai <prompt>
    @commands.command(name="ai", help="Generate text using the default AI model. Usage: !ai <prompt>")
    async def ai_whitespace(self, ctx, *, prompt: str):
        await ctx.trigger_typing()
        try:
            result = generate_text(prompt)
            await ctx.send(result)
        except Exception as e:
            await ctx.send(f"Error: {e}")

    # Whitespace command: !aimodels
    @commands.command(name="aimodels", help="List available AI models. Usage: !aimodels")
    async def ai_models_whitespace(self, ctx):
        models = available_models()
        await ctx.send(f"Available models: {', '.join(models)}")

    # Whitespace command: !aiwith <model> <prompt>
    @commands.command(name="aiwith", help="Generate text using a specific AI model. Usage: !aiwith <model> <prompt>")
    async def ai_with_model_whitespace(self, ctx, model: str, *, prompt: str):
        await ctx.trigger_typing()
        try:
            result = generate_text(prompt, model=model)
            await ctx.send(result)
        except Exception as e:
            await ctx.send(f"Error: {e}")

    # App command: /ai <prompt>
    @app_commands.command(name="ai", description="Generate text using the default AI model.")
    async def ai_app(self, interaction: discord.Interaction, prompt: str):
        await interaction.response.defer(thinking=True)
        try:
            result = generate_text(prompt)
            await interaction.followup.send(result)
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")

    # App command: /aimodels
    @app_commands.command(name="aimodels", description="List available AI models.")
    async def ai_models_app(self, interaction: discord.Interaction):
        models = available_models()
        await interaction.response.send_message(f"Available models: {', '.join(models)}")

    # App command: /aiwith <model> <prompt>
    @app_commands.command(name="aiwith", description="Generate text using a specific AI model.")
    @app_commands.describe(model="Model name", prompt="Prompt to send to the model")
    async def ai_with_model_app(self, interaction: discord.Interaction, model: str, prompt: str):
        await interaction.response.defer(thinking=True)
        try:
            result = generate_text(prompt, model=model)
            await interaction.followup.send(result)
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")

    # Register app commands on cog load
    async def cog_load(self):
        if hasattr(self.bot, "tree"):
            self.bot.tree.add_command(self.ai_app)
            self.bot.tree.add_command(self.ai_models_app)
            self.bot.tree.add_command(self.ai_with_model_app)

async def setup(bot):
    await bot.add_cog(AICommands(bot))