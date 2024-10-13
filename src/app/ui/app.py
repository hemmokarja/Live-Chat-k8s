import logging
import os
import sys

import requests
from flask import Flask, redirect, render_template, request, session, url_for

backend_url = os.environ["BACKEND_URL"]

app = Flask(__name__)
app.config["ENV"] = os.environ["FLASK_ENV"]
app.config["DEBUG"] = os.environ["FLASK_DEBUG"] == "true"
app.config["SECRET_KEY"] = os.environ["FLASK_SECRET_KEY"]

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s][%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

@app.route("/", methods=["GET"])
def index():
    session.clear()  # clear session when returning to the landing page
    logger.info("Landing page accessed, session cleared")
    return render_template("home.html")

@app.route("/check_username", methods=["POST"])
def check_username():
    username = request.form.get("username")
    logger.info(f"Checking availability for username '{username}'")

    response = requests.post(
        f"{backend_url}/api/check_username", json={"username": username}
    )
    data = response.json()

    if not data["available"]:
        logger.info(f"Username '{username}' is already taken.")
        return render_template(
            "home.html", error="Username is already taken. Please choose another."
        )
    
    logger.info(f"Username '{username}' is available. Redirecting to lobby.")
    session["username"] = username
    return redirect(url_for("lobby"))

@app.route("/lobby")
def lobby():
    username = session.get("username")
    if not username:
        logger.warning(
            "User attempted to access lobby without a valid session. Redirecting to "
            "index."
        )
        return redirect(url_for("index"))
    
    logger.info(f"User '{username}' accessed the lobby")
    return render_template("lobby.html", username=username)

@app.route("/chat_room")
def chat_room():
    room_id = request.args.get("room_id")
    username = session.get("username")

    if not room_id or not username:
        logger.warning("Missing room_id or username. Redirecting to lobby.")
        return redirect(url_for("lobby"))

    logger.info(f"User '{username}' attempting to access room '{room_id}'")

    response = requests.post(
        f"{backend_url}/api/verify_room_access",
        json={"room_id": room_id, "username": username}
    )
    data = response.json()

    if not data.get("authorized"):
        logger.warning(
            f"Unauthorized access attempt by user '{username}' to room '{room_id}'"
        )
        return render_template("unauthorized.html"), 403

    logger.info(f"User '{username}' authorized to access room '{room_id}'")
    return render_template("chat_room.html", room_id=room_id, username=username)

@app.route("/unauthorized")
def unauthorized():
    logger.warning("Unauthorized access page rendered")
    return render_template("unauthorized.html"), 403

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=os.environ["CONTAINER_PORT"])
