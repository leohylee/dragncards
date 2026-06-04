"""
Phone on/off button for the LCG apps EC2 instance (DragnCards + RingsDB + MarvelCDB).

Deployed as a Lambda behind a Function URL (auth type NONE; we guard with a
shared secret token instead). Save the URL as a home-screen bookmark / iOS
Shortcut.

Behaviour (query string):
  ?token=SECRET                -> HTML control panel showing current state + buttons
  ?token=SECRET&action=start   -> StartInstances, then show panel
  ?token=SECRET&action=stop    -> StopInstances, then show panel

Environment variables:
  INSTANCE_ID   e.g. i-0123456789abcdef0
  SECRET_TOKEN  a long random string; must match ?token=

After a start it takes ~2-3 min for the box to boot, update DNS, and bring the
containers up before https://lcg.leohyl.app is live.
"""
import json
import os

import boto3

ec2 = boto3.client("ec2")
INSTANCE_ID = os.environ["INSTANCE_ID"]
SECRET_TOKEN = os.environ["SECRET_TOKEN"]
SITE_URL = os.environ.get("SITE_URL", "https://lcg.leohyl.app")


def _state():
    r = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    return r["Reservations"][0]["Instances"][0]["State"]["Name"]


def _html(state, msg=""):
    note = f"<p>{msg}</p>" if msg else ""
    return f"""<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LCG apps power</title>
<style>
 body{{font-family:system-ui;margin:0;padding:2rem;text-align:center;background:#111;color:#eee}}
 .state{{font-size:1.4rem;margin:1rem 0}}
 a.btn{{display:inline-block;margin:.5rem;padding:1rem 2rem;border-radius:.75rem;
       text-decoration:none;font-size:1.2rem;color:#fff}}
 .start{{background:#1f8f3a}} .stop{{background:#b32424}} .open{{background:#2451b3}}
</style></head><body>
 <h1>LCG apps</h1>
 <div class="state">status: <b>{state}</b></div>
 {note}
 <a class="btn start" href="?token={SECRET_TOKEN}&action=start">Start</a>
 <a class="btn stop"  href="?token={SECRET_TOKEN}&action=stop">Stop</a>
 <br>
 <a class="btn open" href="{SITE_URL}">Open site</a>
 <a class="btn"      href="?token={SECRET_TOKEN}" style="background:#444">Refresh</a>
</body></html>"""


def _resp(body, status=200):
    return {
        "statusCode": status,
        "headers": {"content-type": "text/html; charset=utf-8"},
        "body": body,
    }


def handler(event, _context):
    params = event.get("queryStringParameters") or {}
    if params.get("token") != SECRET_TOKEN:
        return _resp("<h1>403 forbidden</h1>", 403)

    msg = ""
    action = params.get("action")
    if action == "start":
        if _state() in ("stopped", "stopping"):
            ec2.start_instances(InstanceIds=[INSTANCE_ID])
            msg = "Starting… give it ~2-3 min, then Open site."
        else:
            msg = "Already running / starting."
    elif action == "stop":
        if _state() in ("running", "pending"):
            ec2.stop_instances(InstanceIds=[INSTANCE_ID])
            msg = "Stopping…"
        else:
            msg = "Already stopped / stopping."

    return _resp(_html(_state(), msg))
