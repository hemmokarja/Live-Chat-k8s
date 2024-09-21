from flask import Flask, render_template, request, redirect, url_for, flash
from flask_socketio import SocketIO, emit
import requests
import socketio as client_socketio

app = Flask(__name__)
app.secret_key = "supersecretkey"
socketio = SocketIO(app, cors_allowed_origins="*")

LOBBY_SERVICE_URL = "http://localhost:5002"

# create a Socket.IO client to connect to the lobby service
lobby_sio = client_socketio.Client()
lobby_sio.connect(LOBBY_SERVICE_URL)


@app.route("/", methods=["GET", "POST"])
def home():
    if request.method == "POST":
        username = request.form.get("username")
        if not username:
            return render_template("home.html", error="Please, enter a username!")

        response = requests.post(
            f"{LOBBY_SERVICE_URL}/login", data={"username": username}
        )

        if response.status_code == 200:
            return redirect(url_for("lobby"))
        else:
            error_message = response.json().get("message", "Something went wrong!")
            return render_template("home.html", error=error_message)

    return render_template("home.html")


@app.route("/lobby")
def lobby():
    return render_template("lobby.html")


@socketio.on("connect")
def handle_connect():
    print("Client connected to frontend service")
    # when a new client connects, request the current user list from the Lobby Service
    response = requests.get(f"{LOBBY_SERVICE_URL}/users")
    if response.status_code == 200:
        users = response.json().get("users", [])
        emit("user_update", {"users": users})


@lobby_sio.on("user_update")
def forward_user_update(data):
    socketio.emit("user_update", data)


if __name__ == "__main__":
    socketio.run(app, port=5001, debug=True)