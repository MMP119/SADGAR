from fastapi import FastAPI, HTTPException
import subprocess
import os
import json
from datetime import datetime

app = FastAPI(title="Control Failover/Failback con pgBackRest")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STANZA_NAME = "imdb-cluster"

@app.get("/")
def menu():
    return {
        "Comandos Disponibles": {
            "Failover/Failback": {
                "Failover": "curl -X POST http://127.0.0.1:8088/failover",
                "Failback": "curl -X POST http://127.0.0.1:8088/failback"
            },
            "Backups con pgBackRest": {
                "Backup Completo": "curl -X POST http://127.0.0.1:8088/backup/full",
                "Backup Incremental": "curl -X POST http://127.0.0.1:8088/backup/incremental",
                "Backup Diferencial": "curl -X POST http://127.0.0.1:8088/backup/differential",
                "Listar Backups": "curl -X GET http://127.0.0.1:8088/backup/list",
                "Verificar Backups": "curl -X POST http://127.0.0.1:8088/backup/verify",
                "Restore": "curl -X POST http://127.0.0.1:8088/backup/restore -d '{\"backup_set\":\"latest\"}'"
            }
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

@app.post("/backup/full")
def backup_completo():
    """Ejecuta un backup completo con pgBackRest"""
    try:
        cmd = [
            "docker", "exec", "postgres_master", 
            "pgbackrest", "--stanza=" + STANZA_NAME, "--type=full", "backup"
        ]
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        
        # Obtener información del backup
        info_cmd = [
            "docker", "exec", "postgres_master",
            "pgbackrest", "--stanza=" + STANZA_NAME, "--output=json", "info"
        ]
        info_output = subprocess.check_output(info_cmd)
        backup_info = json.loads(info_output.decode())
        
        return {
            "status": "ok",
            "tipo": "backup_completo",
            "timestamp": datetime.now().isoformat(),
            "info": backup_info,
            "salida": output.decode()
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error en backup: {e.output.decode()}")

@app.post("/backup/incremental")
def backup_incremental():
    """Ejecuta un backup incremental con pgBackRest"""
    try:
        cmd = [
            "docker", "exec", "postgres_master", 
            "pgbackrest", "--stanza=" + STANZA_NAME, "--type=incr", "backup"
        ]
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        
        info_cmd = [
            "docker", "exec", "postgres_master",
            "pgbackrest", "--stanza=" + STANZA_NAME, "--output=json", "info"
        ]
        info_output = subprocess.check_output(info_cmd)
        backup_info = json.loads(info_output.decode())
        
        return {
            "status": "ok",
            "tipo": "backup_incremental",
            "timestamp": datetime.now().isoformat(),
            "info": backup_info,
            "salida": output.decode()
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error en backup: {e.output.decode()}")

@app.post("/backup/differential")
def backup_diferencial():
    """Ejecuta un backup diferencial con pgBackRest"""
    try:
        cmd = [
            "docker", "exec", "postgres_master", 
            "pgbackrest", "--stanza=" + STANZA_NAME, "--type=diff", "backup"
        ]
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        
        info_cmd = [
            "docker", "exec", "postgres_master",
            "pgbackrest", "--stanza=" + STANZA_NAME, "--output=json", "info"
        ]
        info_output = subprocess.check_output(info_cmd)
        backup_info = json.loads(info_output.decode())
        
        return {
            "status": "ok",
            "tipo": "backup_diferencial",
            "timestamp": datetime.now().isoformat(),
            "info": backup_info,
            "salida": output.decode()
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error en backup: {e.output.decode()}")

@app.get("/backup/list")
def listar_backups():
    """Lista todos los backups disponibles"""
    try:
        cmd = [
            "docker", "exec", "postgres_master",
            "pgbackrest", "--stanza=" + STANZA_NAME, "--output=json", "info"
        ]
        output = subprocess.check_output(cmd)
        backup_info = json.loads(output.decode())
        
        return {
            "status": "ok",
            "backups": backup_info
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error al listar backups: {e.output.decode()}")

@app.post("/backup/verify")
def verificar_backups():
    """Verifica la integridad de los backups"""
    try:
        cmd = [
            "docker", "exec", "postgres_master",
            "pgbackrest", "--stanza=" + STANZA_NAME, "check"
        ]
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        
        return {
            "status": "ok",
            "verificacion": "exitosa",
            "salida": output.decode()
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error en verificación: {e.output.decode()}")

@app.post("/backup/restore")
def restaurar_backup(backup_request: dict):
    """Restaura desde un backup específico
    
    Parámetros:
    - backup_set: ID del backup o 'latest' para el más reciente
    - target_time: (opcional) Para Point-in-Time Recovery
    """
    try:
        backup_set = backup_request.get("backup_set", "latest")
        target_time = backup_request.get("target_time")
        
        # Construir comando de restore
        cmd = [
            "docker", "exec", "postgres_master",
            "pgbackrest", "--stanza=" + STANZA_NAME, "--delta"
        ]
        
        if target_time:
            cmd.extend(["--type=time", f"--target={target_time}"])
        
        cmd.append("restore")
        
        # Detener PostgreSQL primero
        stop_cmd = ["docker", "exec", "postgres_master", "pg_ctl", "stop", "-D", "/var/lib/postgresql/data"]
        subprocess.run(stop_cmd)
        
        # Ejecutar restore
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        
        # Reiniciar PostgreSQL
        start_cmd = ["docker", "exec", "postgres_master", "pg_ctl", "start", "-D", "/var/lib/postgresql/data"]
        subprocess.run(start_cmd)
        
        return {
            "status": "ok",
            "restore": "exitoso",
            "backup_set": backup_set,
            "target_time": target_time,
            "salida": output.decode()
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error en restore: {e.output.decode()}")

@app.get("/backup/status")
def estado_backups():
    """Obtiene el estado actual del sistema de backups"""
    try:
        # Verificar estado de pgBackRest
        cmd = [
            "docker", "exec", "postgres_master",
            "pgbackrest", "--stanza=" + STANZA_NAME, "--output=json", "info"
        ]
        output = subprocess.check_output(cmd)
        backup_info = json.loads(output.decode())
        
        # Obtener estadísticas adicionales
        stats = {
            "stanza": STANZA_NAME,
            "ultima_verificacion": datetime.now().isoformat(),
            "total_backups": 0,
            "ultimo_backup": None
        }
        
        if backup_info and len(backup_info) > 0:
            stanza_info = backup_info[0]
            if 'backup' in stanza_info:
                stats["total_backups"] = len(stanza_info['backup'])
                if stanza_info['backup']:
                    stats["ultimo_backup"] = stanza_info['backup'][-1]
        
        return {
            "status": "ok",
            "estadisticas": stats,
            "info_completa": backup_info
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error al obtener estado: {e.output.decode()}")