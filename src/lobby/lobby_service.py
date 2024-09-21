from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

users = []

@app.route("/login", methods=["POST"])
def login():
    username = request.form.get("username")
    
    if not username:
        return jsonify({"message": "Username is required!"}), 400

    if username in users:
        return jsonify({"message": "Username already taken!"}), 400

    users.append(username)

    # broadcast the updated user list to all connected clients
    socketio.emit("user_update", {"users": users})

    return jsonify({"message": "User added successfully!", "users": users}), 200


@app.route("/users", methods=["GET"])
def get_users():
    return jsonify({"users": users})


@socketio.on("connect")
def handle_connect():
    emit("user_update", {"users": users})


@socketio.on("disconnect")
def handle_disconnect():
    # handle user leaving logic here
    pass


if __name__ == "__main__":
    socketio.run(app, port=5002, debug=True)
