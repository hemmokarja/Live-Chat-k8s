import requests
from flask import Flask, render_template, request, session, redirect, url_for, jsonify

app = Flask(__name__)
app.config["SECRET_KEY"] = "your_secret_key"


BACKEND_URL = "http://localhost:5002"


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

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
