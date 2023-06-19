from scripts.utils.kakarot import (deploy)
import asyncio

async def main():
    counter = await deploy("PlainOpcodes", 'Counter')

if __name__ == "__main__":
    asyncio.run(main())