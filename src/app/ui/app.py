import os

import requests
from flask import Flask, redirect, render_template, request, session, url_for

backend_url = os.environ["BACKEND_URL"]

app = Flask(__name__)
app.config["ENV"] = os.environ["FLASK_ENV"]
app.config["DEBUG"] = os.environ["FLASK_DEBUG"] == "true"
app.config["SECRET_KEY"] = os.environ["FLASK_SECRET_KEY"]


@app.route("/", methods=["GET"])
def index():
    session.clear()  # Clear session when returning to the landing page
    return render_template("home.html")

@app.route("/check_username", methods=["POST"])
def check_username():
    username = request.form.get("username")
    response = requests.post(
        f"{backend_url}/api/check_username", json={"username": username}
    )
    data = response.json()
    if not data["available"]:
        return render_template(
            "home.html", error="Username is already taken. Please choose another."
        )
    session["username"] = username
    return redirect(url_for("lobby"))

@app.route("/lobby")
def lobby():
    username = session.get("username")
    if not username:
        return redirect(url_for("index"))
    return render_template("lobby.html", username=username)

@app.route("/chat_room")
def chat_room():
    room_id = request.args.get("room_id")
    username = session.get("username")
    if not room_id or not username:
        return redirect(url_for("lobby"))

    response = requests.post(
        f"{backend_url}/api/verify_room_access",
        json={"room_id": room_id, "username": username}
    )
    data = response.json()
    if not data.get("authorized"):
        return render_template("unauthorized.html"), 403

    return render_template("chat_room.html", room_id=room_id, username=username)

@app.route("/unauthorized")
def unauthorized():
    return render_template("unauthorized.html"), 403

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
