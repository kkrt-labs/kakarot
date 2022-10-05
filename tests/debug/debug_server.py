import flask
import logging
import os
import json

log = logging.getLogger("werkzeug")
log.disabled = True
app = flask.Flask(__name__)
app.config["DEBUG"] = True
counter = 0


@app.route("/", methods=["POST"])
def home():
    global counter
    json_formatted_str = json.dumps(flask.request.json, indent=2)
    print(f"debug counter: {counter}")
    print(json_formatted_str)

    counter += 1
    return "success"

app.run(host=os.getenv('IP', '0.0.0.0'), 
            port=int(os.getenv('PORT', 8000)))