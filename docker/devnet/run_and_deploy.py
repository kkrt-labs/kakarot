import subprocess
import time

import requests

devnet = subprocess.Popen(["make", "run"])

alive = False
attempts = 0
max_retries = 10
while not alive and attempts < max_retries:
    try:
        response = requests.get("http://127.0.0.1:5050/is_alive")
        alive = response.text == "Alive!!!"
    except:
        time.sleep(1)
    finally:
        attempts += 1

deploy = subprocess.run(["make", "deploy"])
deploy.check_returncode()

devnet.terminate()
