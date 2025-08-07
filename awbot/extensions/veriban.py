import discord
from discord.ext import commands
from prisma import Prisma  # Assuming Prisma for DB

class VerifyCog(commands.Cog):
    def __init__(self, bot):
        self.bot = bot
        self.db = Prisma()
        self.bad_servers = self.load_bad_servers()  # Cache on init

    async def load_bad_servers(self):
        await self.db.connect()
        bad_servers = await self.db.badserver.find_many()
        await self.db.disconnect()
        return {server.guildId for server in bad_servers}  # Set for fast lookup

    @commands.Cog.listener()
    async def on_member_join(self, member: discord.Member):
        await self.verify_user(member, member.guild)

    @commands.command(name="verify")
    @commands.has_permissions(administrator=True)  # Restrict to admins
    async def verify_command(self, ctx, member: discord.Member):
        await self.verify_user(member, ctx.guild)

    async def verify_user(self, member: discord.Member, guild: discord.Guild):
        # Fetch mutual guilds
        mutual_guilds = {g.id for g in member.mutual_guilds}

        # Check for intersection with bad servers
        bad_matches = mutual_guilds.intersection(self.bad_servers)

        if bad_matches:
            reason = f"User in bad servers: {', '.join(map(str, bad_matches))}. Auto-banned for safety."
            try:
                await guild.ban(member, reason=reason)
                # Log it (e.g., to a mod channel or your logs dir)
                mod_channel = guild.get_channel(YOUR_MOD_CHANNEL_ID)  # Set this!
                if mod_channel:
                    await mod_channel.send(f"Banned {member} - {reason}")
            except discord.Forbidden:
                # Handle missing perms
                print(f"Cannot ban in {guild.name} - missing permissions.")
        else:
            # Optional: Assign verified role
            verified_role = guild.get_role(YOUR_VERIFIED_ROLE_ID)
            if verified_role:
                await member.add_roles(verified_role)
            # Witty welcome
            await member.send("Welcome! You've passed the vibe check. 🚀")

# In your main bot file:
async def setup(bot):
    await bot.add_cog(VerifyCog(bot))
