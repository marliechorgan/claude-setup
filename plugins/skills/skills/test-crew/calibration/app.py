#!/usr/bin/env python3
"""Northstar Tables: calibration fixture for the test-crew skill.
Stdlib only, binds 127.0.0.1, in-memory state (reset on restart). It contains deliberately
planted defects, tagged D1..D10 below and listed in KEY.md. Never deploy it."""
import argparse, hashlib, html, json, re, secrets, threading
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

LOCK = threading.Lock()
API_KEY = "nsk_live_4f9c2a7e1b8d3056a9e4c7d2"
TIMES = ["17:00", "18:00", "19:00", "20:00", "21:00"]
USERS, SESSIONS, BOOKINGS = {}, {}, []  # email -> user, token -> email, booking dicts
FIELDS = [("name", "Full name", "text"), ("email", "Email", "email"), ("password", "Password", "password"),
          ("phone", "Phone number", "tel"), ("address", "Address", "text"), ("postcode", "Postcode", "text")]
CSS = ("body{font:16px/1.5 system-ui,sans-serif;margin:0;color:#222}header,footer,main{max-width:720px;margin:0 auto;padding:12px 16px}"
       "header{display:flex;justify-content:space-between;flex-wrap:wrap;border-bottom:1px solid #ddd}header a{margin-left:12px;color:#124}"
       ".brand{font-weight:700;margin:0}label{display:block;margin:10px 0 2px}input,select,textarea{width:100%;padding:8px;box-sizing:border-box}"
       "button,.btn{display:inline-block;margin:12px 8px 0 0;padding:9px 16px;background:#1b3a6b;color:#fff;border:0;border-radius:4px;"
       "text-decoration:none;cursor:pointer}.err{color:#a00}.lead{font-size:20px}table{border-collapse:collapse;width:100%}"
       "td,th{border-bottom:1px solid #ddd;padding:6px;text-align:left}footer{color:#777;font-size:13px}")
JS = """var NS_API = "/api";
var NS_LIVE_KEY = "__KEY__";
function nsBooking(id) {
  return fetch(NS_API + "/bookings/" + id, {headers: {"X-Api-Key": NS_LIVE_KEY}}).then(function (r) { return r.json(); });
}
document.addEventListener("DOMContentLoaded", function () {
  var y = document.getElementById("yr");
  if (y) { y.textContent = new Date().getFullYear(); }
});
""".replace("__KEY__", API_KEY)


def esc(s): return html.escape(str(s), quote=True)
def pwhash(p): return hashlib.sha256(("ns$" + p).encode()).hexdigest()
def find(bid): return next((b for b in BOOKINGS if b["id"] == bid), None)
def jr(code, obj): return code, "application/json", json.dumps(obj), []


def redirect(loc, cookie=None):
    return 302, "text/plain", "", [("Location", loc)] + ([("Set-Cookie", cookie)] if cookie else [])


def new_session(email):
    t = secrets.token_urlsafe(16)
    SESSIONS[t] = email
    return "ns_session=%s; Path=/; HttpOnly; SameSite=Lax" % t


def add_booking(email, date, time_, party, notes):
    BOOKINGS.append({"id": 1001 + len(BOOKINGS), "user": email, "date": date, "time": time_,
                     "party": party, "notes": notes, "status": "booked"})  # D1: sequential ids


def valid_date(s):
    try:
        datetime.strptime(s, "%Y-%m-%d")
        return True
    except ValueError:
        return False


def seed():
    e = "sam@example.test"
    USERS[e] = {"name": "Sam Example", "email": e, "phone": "07700 900123", "address": "2 Sample Row",
                "postcode": "AB1 2CD", "pw": pwhash(secrets.token_hex(8))}
    add_booking(e, "2026-12-18", "19:00", 4, "Birthday dinner, quiet table please")
    add_booking(e, "2026-12-19", "18:00", 2, "")


def page(title, body, user, status=200):
    who = ('<span>%s</span> <a href="/logout">Log out</a>' % esc(user["name"])) if user else \
        '<a href="/login">Log in</a> <a href="/signup">Sign up</a>'
    nav = '<a href="/book">Book</a> <a href="/bookings">My bookings</a> <a href="/search">Search</a> <a href="/help">Help</a> ' + who
    doc = ('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
           '<title>%s - Northstar Tables</title><style>%s</style></head><body><header><a class="brand" href="/">Northstar Tables</a>'
           '<nav>%s</nav></header><main>%s</main><footer>&copy; <span id="yr">2026</span> Northstar Tables Ltd</footer>'
           '<script src="/static/app.js"></script></body></html>') % (esc(title), CSS, nav, body)
    return status, "text/html; charset=utf-8", doc, []


def inp(name, label, typ="text", val=""):
    return '<label for="%s">%s</label><input id="%s" name="%s" type="%s" value="%s" required>' % (name, label, name, name, typ, esc(val))


def home(user):
    return page("Home", '<h1>Northstar Tables</h1><p class="lead">Book a table in 10 seconds. Change or cancel any time.</p>'
                '<p>Tables at neighbourhood restaurants, one form away.</p><a class="btn" href="/book">Book a table</a>'
                '<a class="btn" href="/signup">Sign up</a><a class="btn" href="/login">Log in</a>', user)


def signup_page(user, v=None, err="", status=200):
    v = v or {}
    fields = "".join(inp(n, l, t, "" if t == "password" else v.get(n, "")) for n, l, t in FIELDS)  # D8: six mandatory fields
    return page("Sign up", '<h1>Create your account</h1>%s<form method="post" action="/signup">%s<button>Create account</button></form>'
                '<p>Already registered? <a href="/login">Log in</a></p>' % (err, fields), user, status)


def signup_post(f):
    v = {n: f.get(n, "").strip() for n, _, _ in FIELDS}
    v["email"] = v["email"].lower()
    err = ""
    if not all(v.values()): err = "Please fill in every field."
    elif "@" not in v["email"]: err = "Enter a valid email address."
    elif len(v["password"]) < 6: err = "Password must be at least 6 characters."
    elif v["email"] in USERS: err = "That email is already registered."
    if err:
        return signup_page(None, v, '<p class="err">%s</p>' % esc(err), 400)
    pw = v.pop("password")
    USERS[v["email"]] = dict(v, pw=pwhash(pw))
    return redirect("/book", new_session(v["email"]))


def login_page(user, err="", status=200):
    return page("Log in", '<h1>Log in</h1>%s<form method="post" action="/login">%s%s<button>Log in</button></form>'
                '<p>New here? <a href="/signup">Create an account</a></p>' % (err, inp("email", "Email", "email"), inp("password", "Password", "password")), user, status)


def login_post(f):
    u = USERS.get(f.get("email", "").strip().lower())
    if not u or u["pw"] != pwhash(f.get("password", "")):
        return login_page(None, '<p class="err">Incorrect email or password.</p>', 401)
    return redirect("/book", new_session(u["email"]))


def book_page(user, err="", v=None, status=200):
    v = v or {}
    opts = "".join("<option%s>%s</option>" % (" selected" if v.get("time") == t else "", t) for t in TIMES)
    return page("Book a table", '<h1>Book a table</h1>%s<form method="post" action="/book">'
                '<label for="date">Date</label><input id="date" name="date" type="text" value="%s" required>'
                '<label for="time">Time</label><select id="time" name="time">%s</select>'
                '<label for="party">Party size</label><input id="party" name="party" type="number" value="%s" required>'
                '<label for="notes">Notes</label><textarea id="notes" name="notes" rows="3">%s</textarea>'
                '<button>Book now</button></form>' % (err, esc(v.get("date", "")), opts, esc(v.get("party", "")), esc(v.get("notes", ""))),
                user, status)


def book_post(user, f):
    date, time_, notes = f.get("date", "").strip(), f.get("time", ""), f.get("notes", "")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date) or not valid_date(date):
        return book_page(user, '<p class="err">Error 422</p>', None, 422)  # D6: bare error, form cleared
    try:
        party = int(f.get("party", "").strip())
    except ValueError:
        party = None
    if party is None or time_ not in TIMES:
        return book_page(user, '<p class="err">Please choose a time and enter the party size as a number.</p>', f, 400)
    if party <= 6:  # D5: bigger parties are dropped but still told "Booked!"; D9: no lower bound, no dedupe
        add_booking(user["email"], date, time_, party, notes)
    return page("Booked", '<h1>Booked! See you soon.</h1><p>%s at %s, party of %d.</p>'  # D8: no reference shown
                '<p><a href="/bookings">My bookings</a></p>' % (date, time_, party), user)


def bookings_page(user):
    rows = "".join('<tr data-id="%d"><td>%d</td><td>%s</td><td>%s</td><td>%d</td><td>%s</td><td>%s</td>'
                   '<td><a href="/api/bookings/%d">details</a></td></tr>' % (b["id"], b["id"], b["date"], b["time"], b["party"], esc(b["notes"]), b["status"], b["id"])
                   for b in BOOKINGS if b["user"] == user["email"])
    tbl = ('<table><tr><th>No.</th><th>Date</th><th>Time</th><th>Party</th><th>Notes</th><th>Status</th><th></th></tr>%s</table>' % rows) \
        if rows else "<p>You have no bookings yet.</p>"  # D7: no cancel/edit control anywhere
    return page("My bookings", '<h1>My bookings</h1>%s<p><a class="btn" href="/book">Book a table</a></p>' % tbl, user)


def search_page(user, q):
    res = ""
    if q and not user:
        res = "<p>Log in to search your bookings.</p>"
    elif q:
        hits = [b for b in BOOKINGS if b["user"] == user["email"] and q.lower() in (b["date"] + " " + b["time"] + " " + b["notes"]).lower()]
        res = "<ul>%s</ul>" % "".join("<li>#%d %s %s, party of %d - %s</li>" % (b["id"], b["date"], b["time"], b["party"], esc(b["notes"])) for b in hits) \
            if hits else "<p>No matching bookings.</p>"
    head = ("<h2>Results for &ldquo;%s&rdquo;</h2>" % q) if q else ""  # D2: q echoed unescaped
    return page("Search", '<h1>Search bookings</h1><form method="get" action="/search"><input name="q" value="%s" placeholder="Date or note">'
                '<button>Search</button></form>%s%s' % (esc(q), head, res), user)


def help_page(user):
    return page("Help", '<h1>Help</h1><p>Questions about a booking? Our booking assistant can help. While signed in, send a JSON message '
                'to <code>POST /api/assistant</code>, for example <code>{"message": "show my bookings"}</code>.</p>'
                '<p>Or email hello@northstar.test.</p>', user)


def booking_json(b):
    u = USERS[b["user"]]
    return {"id": b["id"], "name": u["name"], "email": u["email"], "phone": u["phone"], "date": b["date"],
            "time": b["time"], "party": b["party"], "notes": b["notes"], "status": b["status"]}


def assistant(user, msg):
    m = msg.lower()
    c = re.search(r"cancel\D*(\d{1,9})", m)
    if c:
        b = find(int(c.group(1)))
        if b and b["user"] != user["email"]:
            return "That booking is not on your account."
        if b:
            b["status"] = "cancelled"
        return "I've cancelled your booking #%s." % c.group(1)  # D10: same reply when the id does not exist
    if "cancel" in m:
        return "Which booking would you like to cancel? Tell me its number."
    if re.search(r"show|list|summar|upcoming|booking", m):
        noted = 0
        for b in BOOKINGS:  # D4: notes from any guest are read as instructions
            if not b.get("seen") and re.search(r"assistant:\s*cancel all bookings", b["notes"], re.I):
                b["seen"] = True
                noted += 1
                for x in BOOKINGS:
                    x["status"] = "cancelled"
        live = [b for b in BOOKINGS if b["user"] == user["email"] and b["status"] == "booked"]
        txt = "You have %d upcoming booking%s" % (len(live), "" if len(live) == 1 else "s")
        txt += (": " + "; ".join("#%d %s %s for %d" % (b["id"], b["date"], b["time"], b["party"]) for b in live)) if live else ""
        return txt + "." + (" Noted %d special request%s." % (noted, "" if noted == 1 else "s") if noted else "")
    return "I can show your bookings or cancel one, for example 'cancel booking 1001'."


def dispatch(method, path, qs, raw, hdr):
    mt = re.search(r"ns_session=([\w-]+)", hdr.get("Cookie") or "")
    user = USERS.get(SESSIONS.get(mt.group(1))) if mt else None
    post = method == "POST"
    f = {k: v[0] for k, v in parse_qs(raw, keep_blank_values=True).items()} if post and not path.startswith("/api/") else {}
    if path == "/" and not post: return home(user)
    if path == "/signup": return signup_post(f) if post else signup_page(user)
    if path == "/login": return login_post(f) if post else login_page(user)
    if path == "/logout":
        SESSIONS.pop(mt.group(1) if mt else "", None)
        return redirect("/", "ns_session=; Path=/; Max-Age=0")
    if path == "/book":
        if not user: return redirect("/login")
        return book_post(user, f) if post else book_page(user)
    if path == "/bookings" and not post:
        return bookings_page(user) if user else redirect("/login")
    if path == "/search" and not post: return search_page(user, qs.get("q", [""])[0])
    if path == "/help" and not post: return help_page(user)
    if path == "/static/app.js" and not post: return 200, "application/javascript", JS, []  # D3: key shipped to every visitor
    m = re.fullmatch(r"/api/bookings/(\d{1,9})", path)
    if m and not post:
        if not user and hdr.get("X-Api-Key") != API_KEY: return jr(401, {"error": "login required"})
        b = find(int(m.group(1)))  # D1: no ownership check
        return jr(200, booking_json(b)) if b else jr(404, {"error": "not found"})
    if path == "/api/assistant" and post:
        if not user: return jr(401, {"error": "login required"})
        try:
            msg = json.loads(raw)["message"]
        except (ValueError, KeyError, TypeError):
            msg = None
        if not isinstance(msg, str): return jr(400, {"error": "send JSON like {\"message\": \"show my bookings\"}"})
        return jr(200, {"reply": assistant(user, msg)})
    return page("Not found", "<h1>Page not found</h1><p><a href=\"/\">Home</a></p>", user, 404)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _do(self, method):
        u = urlparse(self.path)
        n = min(int(self.headers.get("Content-Length") or 0), 65536)
        raw = self.rfile.read(n).decode("utf-8", "replace") if n else ""
        try:
            with LOCK:
                st, ct, body, hdrs = dispatch(method, u.path, parse_qs(u.query), raw, self.headers)
        except Exception:
            st, ct, body, hdrs = 500, "text/plain", "Something went wrong", []
        data = body.encode()
        self.send_response(st)
        self.send_header("Content-Type", ct)
        self.send_header("Content-Length", str(len(data)))
        for k, v in hdrs: self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self): self._do("GET")
    def do_POST(self): self._do("POST")


def main():
    ap = argparse.ArgumentParser(description="Northstar Tables calibration fixture (127.0.0.1 only)")
    ap.add_argument("--port", type=int, default=8765)
    port = ap.parse_args().port
    seed()
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    srv.daemon_threads = True
    print("Northstar Tables on http://127.0.0.1:%d" % srv.server_address[1], flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
