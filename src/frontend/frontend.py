import requests
from flask import Flask, redirect, render_template, request, session, url_for

BACKEND_URL = "http://nginx/api"

app = Flask(__name__)
app.config["'ENV"] = "production"
app.config["DEBUG"] = False
app.config["SECRET_KEY"] = "your_secret_key"


@app.route("/", methods=["GET"])
def index():
    session.clear()  # Clear session when returning to the landing page
    return render_template("home.html")

@app.route("/check_username", methods=["POST"])
def check_username():
    username = request.form.get("username")
    response = requests.post(
        f"{BACKEND_URL}/check_username", json={"username": username}
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
        f"{BACKEND_URL}/verify_room_access",
        json={"room_id": room_id, "username": username}
    )
    data = response.json()
    if not data.get("authorized"):
        return render_template("unauthorized.html"), 403
    
    # TODO remove after not necessary
    response = requests.get(f"{BACKEND_URL}/container_id")
    data = response.json()
    container_id = data.get("container_id")

    return render_template("chat_room.html", room_id=room_id, username=username, container_id=container_id)

@app.route("/unauthorized")
def unauthorized():
    return render_template("unauthorized.html"), 403

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
