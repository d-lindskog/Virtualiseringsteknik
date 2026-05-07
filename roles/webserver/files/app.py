from flask import Flask, request, render_template_string

app = Flask(__name__)

login_page = """
<!DOCTYPE html>
<html>
<head>
    <title>Login</title>
</head>
<body>
    <h1>Logga in</h1>

    <form method="POST" action="/login">
        <label>Användarnamn:</label><br>
        <input type="text" name="username"><br><br>

        <label>Lösenord:</label><br>
        <input type="password" name="password"><br><br>

        <button type="submit">Logga in</button>
    </form>
</body>
</html>
"""

@app.route("/")
def index():
    return render_template_string(login_page)

@app.route("/login", methods=["POST"])
def login():
    username = request.form.get("username")
    password = request.form.get("password")

    if not username or not password:
        return "Användarnamn och lösenord krävs", 400

    return f"Inloggningsförsök mottaget för användare: {username}. Nästa steg är Keycloak."

@app.route("/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
    