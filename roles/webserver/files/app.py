from flask import Flask, redirect, session, url_for, render_template_string

app = Flask(__name__)
app.secret_key = "byt-denna-senare"

home_page = """
<!DOCTYPE html>
<html>
<head>
    <title>Webserver</title>
</head>
<body>
    <h1>Webserver i DMZ</h1>

    {% if user %}
        <p>Inloggad som {{ user }}</p>

        <a href="/dashboard">Gå till dashboard</a>
        <br><br>

        <a href="/logout">Logga ut</a>

    {% else %}
        <p>Du är inte inloggad.</p>

        <a href="/login">Logga in med Keycloak</a>
    {% endif %}

</body>
</html>
"""

dashboard_page = """
<!DOCTYPE html>
<html>
<head>
    <title>Dashboard</title>
</head>
<body>

    <h1>Dashboard</h1>

    <p>Inloggad som {{ user }}</p>

    <p>Data från databasen: {{ message }}</p>

    <a href="/logout">Logga ut</a>

</body>
</html>
"""

@app.route("/")
def home():
    user = session.get("user")
    return render_template_string(home_page, user=user)

@app.route("/login")
def login():

    # Nästa steg:
    # här ska användaren skickas vidare till Keycloak

    return redirect(url_for("callback"))

@app.route("/auth/callback")
def callback():

    # Nästa steg:
    # här ska Flask ta emot användaren från Keycloak
    # och skapa session efter lyckad inloggning

    session["user"] = "student"

    return redirect(url_for("dashboard"))

@app.route("/dashboard")
def dashboard():

    if "user" not in session:
        return redirect(url_for("login"))

    # Nästa steg:
    # här ska appen läsa databasuppgifter från Vault
    # och sedan hämta data från databasen

    message = "Hej från databasen"

    return render_template_string(
        dashboard_page,
        user=session["user"],
        message=message
    )

@app.route("/logout")
def logout():

    session.clear()

    return redirect(url_for("home"))

@app.route("/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
    