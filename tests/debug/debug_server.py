import flask
from flask import request
import logging
import os

log = logging.getLogger("werkzeug")
log.disabled = True
app = flask.Flask(__name__)
app.config["DEBUG"] = True
counter = 0


@app.route("/", methods=["POST"])
def home():
    global counter
    print(counter, request.json)
    counter += 1
    return "success"

app.run(host=os.getenv('IP', '0.0.0.0'), 
            port=int(os.getenv('PORT', 8000)))