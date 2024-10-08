from flask import Flask, request, jsonify, abort
import time
import json
from functools import wraps

app = Flask(__name__)

# Set the correct sequence based on the SVG file names
correct_sequence = [5, 30, 22, 31, 8, 14, 1]

# File to store blocked IPs
BLOCKED_IPS_FILE = 'blocked_ips.json'

def load_blocked_ips():
    try:
        with open(BLOCKED_IPS_FILE, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        return {}

def save_blocked_ips(blocked_ips):
    with open(BLOCKED_IPS_FILE, 'w') as f:
        json.dump(blocked_ips, f)

def check_ip_blocked(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        ip = request.remote_addr
        blocked_ips = load_blocked_ips()
        if ip in blocked_ips:
            if time.time() - blocked_ips[ip] < 48 * 3600:  # 48 hours in seconds
                abort(403, description="Your IP is blocked for 48 hours due to incorrect attempts.")
            else:
                del blocked_ips[ip]
                save_blocked_ips(blocked_ips)
        return f(*args, **kwargs)
    return decorated_function

@app.route('/check-sequence', methods=['POST'])
@check_ip_blocked
def check_sequence():
    data = request.json
    user_sequence = data['sequence']
    
    if user_sequence == correct_sequence:
        return jsonify({'correct': True, 'nextPage': '/success'})
    else:
        # Block the IP
        ip = request.remote_addr
        blocked_ips = load_blocked_ips()
        blocked_ips[ip] = time.time()
        save_blocked_ips(blocked_ips)
        return jsonify({'correct': False, 'message': 'Incorrect sequence. Your IP has been blocked for 48 hours.'})

@app.route('/')
@check_ip_blocked
def index():
    return app.send_static_file('index.html')

@app.route('/success')
@check_ip_blocked
def success():
    return "Congratulations! You've solved the puzzle."

if __name__ == '__main__':
    app.run(debug=True)