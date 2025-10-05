from fastapi import FastAPI
import subprocess
import os

app = FastAPI(title="Control Failover/Failback")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

@app.get("/")
def menu():
    return {
        "Comandos": {
            "Failover": "curl -X POST http://127.0.0.1:8088/failover",
            "Failback": "curl -X POST http://127.0.0.1:8088/failback"
        }
    }

@app.post("/failover")
def ejecutar_failover():
    script_path = os.path.join(BASE_DIR, "failover.sh")
    try:
        output = subprocess.check_output(["bash", script_path], stderr=subprocess.STDOUT)
        return {"status": "ok", "salida": output.decode()}
    except subprocess.CalledProcessError as e:
        return {"status": "error", "salida": e.output.decode()}

@app.post("/failback")
def ejecutar_failback():
    script_path = os.path.join(BASE_DIR, "failback.sh")
    try:
        output = subprocess.check_output(["bash", script_path], stderr=subprocess.STDOUT)
        return {"status": "ok", "salida": output.decode()}
    except subprocess.CalledProcessError as e:
        return {"status": "error", "salida": e.output.decode()}
