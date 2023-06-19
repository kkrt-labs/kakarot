import asyncio

from scripts.utils.kakarot import deploy


async def main():
    await deploy("PlainOpcodes", "Counter")


if __name__ == "__main__":
    asyncio.run(main())
