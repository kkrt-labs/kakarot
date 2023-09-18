import logging
import subprocess
import time

import requests

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

logger.info("⏳ Starting devnet in background")
devnet = subprocess.Popen(
    ["make", "run"], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT
)

alive = False
attempts = 0
max_retries = 10
while not alive and attempts < max_retries:
    try:
        response = requests.get("http://127.0.0.1:5050/is_alive")
        alive = response.text == "Alive!!!"
    # trunk-ignore(ruff/E722)
    except:
        time.sleep(1)
    finally:
        attempts += 1

logger.info("✅ starknet-devnet live")

deploy = subprocess.run(["make", "deploy"])
deploy.check_returncode()

devnet.terminate()
devnet.wait()
