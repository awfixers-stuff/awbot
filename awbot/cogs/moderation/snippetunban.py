import discord
from discord.ext import commands

from prisma.enums import CaseType
from awbot.bot import awbot
from awbot.utils import checks
from awbot.utils.flags import SnippetUnbanFlags
from awbot.utils.functions import generate_usage

from . import ModerationCogBase


class SnippetUnban(ModerationCogBase):
    def __init__(self, bot: awbot) -> None:
        super().__init__(bot)
        self.snippet_unban.usage = generate_usage(self.snippet_unban, SnippetUnbanFlags)

    @commands.hybrid_command(
        name="snippetunban",
        aliases=["sub"],
    )
    @commands.guild_only()
    @checks.has_pl(3)
    async def snippet_unban(
        self,
        ctx: commands.Context[awbot],
        member: discord.Member,
        *,
        flags: SnippetUnbanFlags,
    ) -> None:
        """
        Remove a snippet ban from a member.

        Parameters
        ----------
        ctx : commands.Context[awbot]
            The context object.
        member : discord.Member
            The member to remove snippet ban from.
        flags : SnippetUnbanFlags
            The flags for the command. (reason: str, silent: bool)
        """
        assert ctx.guild

        # Check if user is snippet banned
        if not await self.is_snippetbanned(ctx.guild.id, member.id):
            await ctx.send("User is not snippet banned.", ephemeral=True)
            return

        # Check if moderator has permission to snippet unban the member
        if not await self.check_conditions(ctx, member, ctx.author, "snippet unban"):
            return

        # Execute snippet unban with case creation and DM
        await self.execute_mod_action(
            ctx=ctx,
            case_type=CaseType.SNIPPETUNBAN,
            user=member,
            reason=flags.reason,
            silent=flags.silent,
            dm_action="snippet unbanned",
            # Use dummy coroutine for actions that don't need Discord API calls
            actions=[(self._dummy_action(), type(None))],
        )


async def setup(bot: awbot) -> None:
    await bot.add_cog(SnippetUnban(bot))
