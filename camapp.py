from flask import Flask, Response
from picamera2 import Picamera2, Preview
import io
import time

app = Flask(__name__)

def init_camera():
    try:
        picam2 = Picamera2()
        picam2.configure(picam2.create_still_configuration(main={"size": (1280, 720)}))
        picam2.start()
        return picam2
    except RuntimeError as e:
        print(f"Error initializing camera: {e}")
        return None

def gen_frames():
    picam2 = init_camera()
    if picam2 is None:
        return

    stream = io.BytesIO()

    try:
        while True:
            picam2.capture_file(stream, format='jpeg')
            stream.seek(0)
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + stream.read() + b'\r\n')
            stream.seek(0)
            stream.truncate()
    except GeneratorExit:
        picam2.stop()
        print("Stopped camera streaming.")
    except Exception as e:
        print(f"Error during frame generation: {e}")
        picam2.stop()
    finally:
        picam2.stop()
        picam2.close()

@app.route('/video_feed')
def video_feed():
    return Response(gen_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
