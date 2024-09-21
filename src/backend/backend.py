from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit

app = Flask(__name__)
app.config["SECRET_KEY"] = "your_secret_key"
socketio = SocketIO(
    app, cors_allowed_origins=["http://localhost:5001", "http://127.0.0.1:5001"]
)

connected_users = {}

def _list_users(connected_users):
    return list(connected_users.values())

@app.route("/")
def index():
    return "WebSocket server running!"

# check username availability 
@app.route("/check_username", methods=["POST"])
def check_username():
    data = request.get_json()
    username = data.get("username")
    if username in connected_users.values():
        return jsonify({"available": False}), 200
    return jsonify({"available": True}), 200

# handle connection
@socketio.on("connect")
def handle_connect():
    username = request.args.get("username")
    if not username:
        return False  # reject the connection
    connected_users[request.sid] = username
    emit("update_user_list", _list_users(connected_users), broadcast=True)

# handle disconnection
@socketio.on("disconnect")
def handle_disconnect():
    if request.sid in connected_users:
        del connected_users[request.sid]
        emit("update_user_list", _list_users(connected_users), broadcast=True)


if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5002)
